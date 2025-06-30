------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
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
-----------------------------------------------------------------------------
-- Entity:      busif5x
-- File:        bufis5x.vhd
-- Author:      Magnus Hjorth, Frontgrade Gaisler
-- Description: AHB bus interface for LEON5 including store buffer and snoop
--              pipeline
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.l5nv_shared.all;
use gaisler.busif5_types.all;

entity busif5x is
  generic (
    hindex    : integer range 0 to 15;
    ilinesize : integer range 4 to 8;
    dways     : integer range 1 to 4;
    dlinesize : integer range 4 to 8;
    dwaysize  : integer range 1 to 256;
    busw      : integer;                -- AHB data bus width
    rbusw     : integer;                -- AHB data bus width for rddata muxing (>=busw)
    sigbusw   : integer;                -- Data bus width of signals, can be set >=rbusw for convenience
    abitso     : integer;               -- AHB address out bus width
    abitsi    : integer;                -- AHB address in bus width (normally same as abitso)
    sigaw     : integer;                -- Signal width >= abitso,abitsi for convenience
    ibusw     : integer;                -- Bus if width for read data
    hburstw   : integer                 -- For convenience
--pragma translate_off
      ; biftrace : integer := 0;
      busid : string
--pragma translate_on
    );
  port (
    clk            : in  std_ulogic;
    rstn           : in  std_ulogic;
    -- Endianness control
    endian         : in  std_ulogic;
    -- AHB master port
    ahbi_hready    : in std_ulogic;
    ahbi_hgrant    : in std_ulogic;
    ahbi_hrdata    : in std_logic_vector(sigbusw-1 downto 0);
    ahbi_hresp     : in std_logic_vector(1 downto 0);
    ahbo_hbusreq   : out std_ulogic;
    ahbo_hlock     : out std_ulogic;
    ahbo_htrans    : out std_logic_vector(1 downto 0);
    ahbo_haddr     : out std_logic_vector(sigaw-1 downto 0);
    ahbo_hwrite    : out std_ulogic;
    ahbo_hsize     : out std_logic_vector(2 downto 0);
    ahbo_hburst    : out std_logic_vector(hburstw-1 downto 0);
    ahbo_hprot     : out std_logic_vector(3 downto 0);
    ahbo_hwdata    : out std_logic_vector(sigbusw-1 downto 0);
    -- AHB snoop port
    ahbsi_htrans   : in std_logic_vector(1 downto 0);
    ahbsi_haddr    : in std_logic_vector(sigaw-1 downto 0);
    ahbsi_hwrite   : in std_ulogic;
    ahbsi_hsize    : in std_logic_vector(2 downto 0);
    ahbsi_hmaster  : in std_logic_vector(3 downto 0);
    -- Cache controller interface
    bifi_bifop     : in  std_logic_vector(3 downto 0);
    bifi_busaddr   : in  std_logic_vector(abitso-1 downto 0);
    bifi_widebus   : in  std_ulogic;
    bifi_size      : in  std_logic_vector(1 downto 0);
    bifi_stdata    : in  std_logic_vector(63 downto 0);
    bifi_nosnoop   : in  std_ulogic;
    bifi_su        : in  std_ulogic;
    bifi_mmuacc    : in  std_ulogic;          -- 0=regular, 1=PTE
    bifi_maskwerr  : in  std_logic_vector(1 downto 0);
    bifi_wcomb     : in  std_ulogic;          -- potential write combining
    bifi_dlfway    : in  std_logic_vector(0 to 3);
    -- NW FIXME: Atomic operation
    bifi_lr_set    : in  std_ulogic;
    bifi_lr_clr    : in  std_ulogic;
    --bifi_lr_addr   : in std_logic_vector(sigaw-1 downto 0);
    bifi_snoopen   : in  std_ulogic;
    keeplock       : in  std_ulogic;
    rdbufw         : out std_logic_vector(15 downto 0);
    rdbufwd        : out std_logic_vector(127 downto 0);
    rdbufe         : out std_logic_vector(15 downto 0);
    nrddone        : out std_ulogic;
    nrdstarted     : out std_ulogic;
    errclr         : out std_logic_vector(1 downto 0);
    bifo_ready     : out std_ulogic;
    bifo_idle      : out std_ulogic;
    bifo_sterr     : out std_logic_vector(3 downto 0);
    bifo_locked    : out std_ulogic;
    bifo_dtagupd   : out std_logic_vector(0 to 3);
    bifo_dtaguval  : out std_logic_vector(TAGMAX-3 downto 0);
    bifo_dtagumsb  : out std_logic_vector(7 downto 0);
    bifo_dtaguidx  : out std_logic_vector(IDXMAX-1 downto 0);
    bifo_dtagutype : out std_logic_vector(1 downto 0);  -- 00=snoop, 01=flush, 10=dline fetch, 11=dtag write
    bifo_lr_valid  : out std_ulogic;
    bifo_stpend    : out std_logic_vector(1 downto 0);
    -- Snoop RAM interface
    dtagsindex     : out std_logic_vector(IDXMAX-1 downto 0);
    dtagsen        : out std_logic_vector(0 to 3);
    dtagswrite     : out std_ulogic;
    dtagsdin       : out cram_tags;
    dtagsdout      : in  cram_tags;
    maprindex      : out std_logic_vector(IDXMAX-1 downto 0);
    mapout         : in  std_logic_vector(0 to DWAYS-1)
    );
end;

architecture rtl of busif5x is

  function max(x,y: integer) return integer is
  begin
    if x>y then return x; else return y; end if;
  end max;

  function pick(b: boolean; tv,fv: integer) return integer is
  begin
    if b then return tv; else return fv; end if;
  end pick;

  -- ahb_hwdata register always 64 bit to handle pass-through case
  constant wdw : integer := max(busw, 64);

  constant TAG_HIGH     : integer := abitsi-1;
  constant LINESZMAX    : integer := max(dlinesize,ilinesize);
  constant BUF_HIGH     : integer := log2(LINESZMAX*4)-1;
  constant DLINE_BITS   : integer := log2(dlinesize);
  constant DOFFSET_BITS : integer := 8 +log2(dwaysize) - DLINE_BITS;
  constant DTAG_HIGH    : integer := TAG_HIGH;
  constant DTAG_LOW     : integer := DOFFSET_BITS + DLINE_BITS + 2;
  constant DOFFSET_HIGH : integer := DTAG_LOW - 1;
  constant DOFFSET_LOW  : integer := DLINE_BITS + 2;
  constant ILINE_BITS   : integer := log2(ilinesize);
  constant IOFFSET_LOW  : integer := ILINE_BITS + 2;
  constant ILINE_HIGH   : integer := IOFFSET_LOW - 1;
  constant ILINE_LOW_W  : integer := log2(busw/8);
  constant DLINE_HIGH   : integer := DOFFSET_LOW - 1;
  constant DLINE_LOW_W  : integer := log2(busw/8);

  function getvalidmask(haddr: std_logic_vector; hsize: std_logic_vector; bifop: std_logic_vector; le: std_ulogic; dlsz, ilsz, rbusw: integer) return std_logic_vector is
    variable vmask64: std_logic_vector(1 downto 0);
    variable vmask128: std_logic_vector(3 downto 0);
    variable vmask256: std_logic_vector(7 downto 0);
    variable vmask512: std_logic_vector(15 downto 0);
    variable r: std_logic_vector(15 downto 0);
  begin
    vmask64 := "11";
    if (hsize(2)='0' and hsize(1 downto 0)/="11") then
      if (haddr(2) xor le)='0' then
        vmask64(0) := '0';
      else
        vmask64(1) := '0';
      end if;
    end if;
    vmask128 := vmask64 & vmask64;
    if hsize(2)='0' then
      if (haddr(3) xor le)='0' then
        vmask128(1 downto 0) := "00";
      else
        vmask128(3 downto 2) := "00";
      end if;
    end if;
    vmask256 := vmask128 & vmask128;
    if (haddr(4) xor le)='0' then
      vmask256(3 downto 0) := "0000";
    else
      vmask256(7 downto 4) := "0000";
    end if;
    vmask512 := vmask256 & vmask256;
    if (haddr(5) xor le)='0' then
      vmask512(7 downto 0) := "00000000";
    else
      vmask512(15 downto 8) := "00000000";
    end if;
    -- Diag read   0010 -> repl vmask64
    -- Small fetch 1001 -> repl vmask64 or vmask128 depending on ahb bus width
    -- DLine fetch 1010 -> repl depending on dlinesize
    -- ILine fetch 1011 -> repl depending on ilinesize
    if bifop(3)='1' and bifop(1)='1' then
      if (bifop(0)='0' and dlsz=4) or (bifop(0)='1' and ilsz=4) then
        r := vmask128 & vmask128 & vmask128 & vmask128;
      else
        r := vmask256 & vmask256;
      end if;
    elsif bifop(3)='1' and rbusw > 64 then
      r := vmask128 & vmask128 & vmask128 & vmask128;
    else
      r := vmask64 & vmask64 & vmask64 & vmask64 &
           vmask64 & vmask64 & vmask64 & vmask64;
    end if;
    return r;
  end getvalidmask;

  type accfifoent is record
    bifop      : std_logic_vector(3 downto 0);
    addr       : std_logic_vector(abitso-1 downto 0);
    size       : std_logic_vector(1 downto 0);
    data       : std_logic_vector(63 downto 0);
    nosnoop    : std_ulogic;
    widebus    : std_ulogic;
    -- su status for hprot generation
    su         : std_ulogic;
    -- mmu access
    mmuacc     : std_ulogic;
    -- mask write error
    errmask    : std_ulogic;
    -- "00" - does not combine with next
    -- "01" - might combine with next
    -- "11" - can be combined with next
    wcomb      : std_logic_vector(1 downto 0);
    -- write combining total burst length (power of 2)
    --   0=1 --> 1x128/2ent (busw=128,widebus=1)
    --   1=2 --> 2x128/4ent (busw=128,widebus=1), 2x64/2ent (busw=64,widebus=1)
    --   2=4 --> 4x64/4ent (busw=64,widebus=1), 4x32/2ent (widebus=0)
    --   3=8 --> 8x32/4ent (widebus=0)
    wcblen     : std_logic_vector(1 downto 0);
    -- access should be done with lock held
    lock       : std_ulogic;
  end record;
  type accfifoarr is array(natural range <>) of accfifoent;

  constant accfifoent_none : accfifoent := (
    "0000", (others => '0'), "00", (others => '0'), '0', '0', '0', '0', '0', "00", "00", '0'
    );

  procedure setx(e: out accfifoent) is
  begin
    setx(e.bifop);
    setx(e.addr);
    setx(e.size);
    setx(e.data);
    setx(e.nosnoop);
    setx(e.widebus);
    setx(e.su);
    setx(e.errmask);
    setx(e.wcomb);
    setx(e.wcblen);
    setx(e.lock);
  end setx;

  constant SNTYPE_NONE  : std_logic_vector(2 downto 0) := "000";
  constant SNTYPE_SNOOP : std_logic_vector(2 downto 0) := "001";
  constant SNTYPE_DLFET : std_logic_vector(2 downto 0) := "010";
  constant SNTYPE_RES1  : std_logic_vector(2 downto 0) := "011";
  constant SNTYPE_FLUSH : std_logic_vector(2 downto 0) := "100";
  constant SNTYPE_DTAGW : std_logic_vector(2 downto 0) := "101";
  constant SNTYPE_STAGRX: std_logic_vector(2 downto 0) := "110";
  constant SNTYPE_STAGR : std_logic_vector(2 downto 0) := "111";

  type busif5x_regs is record
    -- AHB output registers
    ahb_hbusreq    : std_ulogic;
    ahb_hlock      : std_ulogic;
    ahb_htrans     : std_logic_vector(1 downto 0);
    ahb_haddr      : std_logic_vector(abitso-1 downto 0);
    ahb_hwrite     : std_ulogic;
    ahb_hsize      : std_logic_vector(2 downto 0);
    ahb_hburst     : std_logic_vector(2 downto 0);
    ahb_hprot      : std_logic_vector(3 downto 0);
    ahb_hwdata     : std_logic_vector(wdw-1 downto 0);
    -- tracks through snoop pipeline but doesn't actually go out on AHB bus
    ahb_nosnoop    : std_ulogic;
    ahb_bifop      : std_logic_vector(3 downto 0);
    ahb_wcomb      : std_logic_vector(1 downto 0);
    -- output in data phase
    ahb_mmuacc    : std_ulogic;
    -- AHB grant state
    granted        : std_ulogic;
    -- AHB pipeline registers
    ahb_phready    : std_ulogic;
    ahb2_hlock     : std_ulogic;
    ahb2_htrans    : std_logic_vector(1 downto 0);
    ahb2_haddr     : std_logic_vector(abitsi-1 downto 0);
    ahb2_sindex    : std_logic_vector(DOFFSET_BITS-1 downto 0);
    ahb2_hwrite    : std_ulogic;
    ahb2_hsize     : std_logic_vector(2 downto 0);
    ahb2_hmaster   : std_logic_vector(3 downto 0);
    ahb2_nosnoop   : std_ulogic;
    ahb2_bifop     : std_logic_vector(3 downto 0);
    ahb2_wcomb     : std_logic_vector(1 downto 0);
    ahb2_inacc     : std_ulogic;
    ahb2_indiag    : std_ulogic;
    ahb2_last      : std_ulogic;
    ahb2_addrmask  : std_logic_vector(15 downto 0);
    ir2_bifop      : std_logic_vector(3 downto 0);
    ir2_wmask      : std_logic_vector(1 downto 0);
    ir2_haddr      : std_logic_vector(7 downto 7);
    regrd          : std_ulogic;
    regrddata      : std_logic_vector(63 downto 0);
    regrderr       : std_ulogic;
    ahb3_wcombdone : std_logic_vector(1 downto 0);
    ahb3_haddr     : std_logic_vector(abitsi-1 downto 0);
    ahb3_sntype    : std_logic_vector(2 downto 0);
    ahb3_waysel    : std_logic_vector(0 to 3);
    ahb3_dtagumsb  : std_logic_vector(7 downto 0);
    ahb4_sntype    : std_logic_vector(2 downto 0);
    ahb4_dtagupd   : std_logic_vector(0 to 3);
    ahb4_dtaguidx  : std_logic_vector(DOFFSET_BITS-1 downto 0);
    ahb4_dtaguval  : std_logic_vector(DTAG_HIGH-DTAG_LOW-1 downto 0);
    ahb4_dtagumsb  : std_logic_vector(7 downto 0);
    ahb4_dtagutype : std_logic_vector(1 downto 0);
    -- Output registers to cache controller
    bifready       : std_ulogic;
    bifidle        : std_ulogic;
    -- Signal that bus is locked and no access in progress
    biflocked      : std_ulogic;
    -- Store error indicator
    sterr          : std_logic_vector(3 downto 0);
    -- raise request flag to avoid livelock
    llctr          : std_logic_vector(7 downto 0);
    -- Access fifo / store buffer
    accfifo        : accfifoarr(0 to 3);
    accfw          : std_logic_vector(1 downto 0);
    accfa          : std_logic_vector(1 downto 0);
    accfd          : std_logic_vector(1 downto 0);
    burstctra      : std_logic_vector(2 downto 0);
    lockstate      : std_ulogic;
    -- write combining timeout counter
    wctoctr        : std_logic_vector(2 downto 0);
    -- AHB error status registers
    ahberr         : std_ulogic;
    ahboerr        : std_ulogic;
    ahberrm        : std_ulogic;
    ahboerrm       : std_ulogic;
    ahberrhaddr    : std_logic_vector(abitsi-1 downto 0);
    ahberrhwrite   : std_ulogic;
    ahberrhsize    : std_logic_vector(2 downto 0);
    ahberrhmaster  : std_logic_vector(3 downto 0);
    errburstfilt   : std_ulogic;
    ahberrtype     : std_logic_vector(1 downto 0);
    ahberracc      : std_logic_vector(4 downto 0);
    stpend         : std_logic_vector(1 downto 0);
    -- Configuration
    icignerr       : std_ulogic;
    dcerrmaskval   : std_ulogic;
    dcerrmask      : std_ulogic;
    dcignerr       : std_ulogic;
    -- NW FIXME: added for NV Atomics
    lr_valid       : std_ulogic;
    lr_addr        : std_logic_vector(abitso-1 downto 0);
  end record;

  constant RRES: busif5x_regs := (
    ahb_hbusreq    => '0',
    ahb_hlock      => '0',
    ahb_htrans     => "00",
    ahb_haddr      => (others => '0'),
    ahb_hwrite     => '0',
    ahb_hsize      => "000",
    ahb_hburst     => "000",
    ahb_hprot      => "0000",
    ahb_hwdata     => (others => '0'),
    ahb_nosnoop    => '0',
    ahb_bifop      => BIFOP_NOP,
    ahb_wcomb      => "00",
    ahb_mmuacc     => '0',
    granted        => '0',
    ahb_phready    => '1',
    ahb2_hlock     => '0',
    ahb2_htrans    => (others => '0'),
    ahb2_haddr     => (others => '0'),
    ahb2_sindex    => (others => '0'),
    ahb2_hwrite    => '0',
    ahb2_hsize     => (others => '0'),
    ahb2_hmaster   => (others => '0'),
    ahb2_nosnoop   => '0',
    ahb2_bifop     => (others => '0'),
    ahb2_wcomb     => "00",
    ahb2_inacc     => '0',
    ahb2_indiag    => '0',
    ahb2_last      => '0',
    ahb2_addrmask  => (others => '0'),
    ir2_bifop      => (others => '0'),
    ir2_wmask      => "00",
    ir2_haddr      => (others => '0'),
    regrd          => '0',
    regrddata      => (others => '0'),
    regrderr       => '0',
    ahb3_wcombdone => "00",
    ahb3_haddr     => (others => '0'),
    ahb3_sntype    => (others => '0'),
    ahb3_waysel    => "0000",
    ahb3_dtagumsb  => (others => '0'),
    ahb4_sntype    => (others => '0'),
    ahb4_dtagupd   => (others => '0'),
    ahb4_dtaguidx  => (others => '0'),
    ahb4_dtaguval  => (others => '0'),
    ahb4_dtagumsb  => (others => '0'),
    ahb4_dtagutype => "00",
    bifready       => '1',
    bifidle        => '1',
    biflocked      => '0',
    sterr          => "0000",
    llctr          => (others => '0'),
    accfifo        => (others => accfifoent_none),
    accfw          => "00",
    accfa          => "00",
    accfd          => "00",
    burstctra      => (others => '1'),
    lockstate      => '0',
    wctoctr        => "000",
    ahberr         => '0',
    ahboerr        => '0',
    ahberrm        => '0',
    ahboerrm       => '0',
    ahberrhaddr    => (others => '0'),
    ahberrhwrite   => '0',
    ahberrhsize    => (others => '0'),
    ahberrhmaster  => (others => '0'),
    errburstfilt   => '0',
    ahberrtype     => (others => '0'),
    ahberracc      => (others => '0'),
    stpend         => "00",
    icignerr       => '0',
    dcerrmaskval   => '0',
    dcerrmask      => '0',
    dcignerr       => '0',
    lr_valid       => '0',
    lr_addr        => (others => '0')
    );

  signal r,nr: busif5x_regs;

--pragma translate_off
  constant biftrace_en : boolean := (biftrace /= 0);
--pragma translate_on

begin

  comb: process(r,rstn,endian,
                ahbi_hready,ahbi_hgrant,ahbi_hrdata,ahbi_hresp,
                ahbsi_htrans,ahbsi_haddr,ahbsi_hwrite,ahbsi_hsize,ahbsi_hmaster,
                bifi_bifop,bifi_busaddr,bifi_widebus,bifi_size,bifi_stdata,
                bifi_nosnoop,bifi_su,bifi_mmuacc,bifi_maskwerr,bifi_wcomb,
                bifi_dlfway,bifi_snoopen,keeplock,
                bifi_lr_set, bifi_lr_clr,
                dtagsdout,mapout)
    variable v         : busif5x_regs;
    variable osni      : snoopram_in_type5;
    variable oerrclr   : std_logic_vector(1 downto 0);
    variable keepreq   : std_ulogic;
    variable masktrans : std_ulogic;
    variable nfent     : accfifoent;
    variable afent     : accfifoent;
    variable dfent     : accfifoent;
    variable vent1     : accfifoent;
    variable vent2     : accfifoent;
    variable ventsel   : std_logic_vector(1 downto 0);
    variable bctrmask  : std_logic_vector(2 downto 0);
    variable vdecway   : std_logic_vector(0 to 3);
    variable wcentvalid    : std_logic_vector(0 to 3);
    variable wcnextvalid   : std_logic_vector(0 to 3);
    variable wckmask   : std_logic_vector(0 to 3);
    variable wcbmask   : std_logic_vector(0 to 3);
    variable datasel   : std_logic_vector((busw/32)*3-1 downto 0);
    variable wctimeout : std_ulogic;
    variable vctra     : std_logic_vector(2 downto 0);
    variable vinc      : std_logic_vector(1 downto 0);
    variable vsel64    : std_logic_vector(1 downto 0);
    variable vsel32    : std_ulogic;
    variable vtag      : std_logic_vector(DTAG_HIGH downto DTAG_LOW);
    variable d64       : std_logic_vector(63 downto 0);
    variable d32       : std_logic_vector(31 downto 0);
    variable virready  : std_ulogic;
    variable regrddone : std_ulogic;
    variable regrddata : std_logic_vector(63 downto 0);
    variable bsetvalid : std_logic_vector(15 downto 0);
    variable bseterror : std_logic_vector(15 downto 0);
    variable bufdata   : std_logic_vector(ibusw-1 downto 0);
    variable bsetdone  : std_ulogic;
    variable bsetstarted: std_ulogic;
    variable spunseena : std_logic_vector(0 to 3);
    variable spunseend : std_logic_vector(0 to 3);
    variable vwmcur    : std_ulogic;
  begin
    v := r;

    oerrclr      := "00";
    osni := snoopram_in5_none;

    regrddone := '0';
    regrddata := (others => '0');

    bsetvalid := (others => '0');
    bseterror := (others => '0');
    bufdata := (others => '0');
    bsetdone := '0';
    bsetstarted := '0';

    -- NW FIXME: added for NV atomics
    --------------------------------------------------------------------------
    -- LR atomics 
    --------------------------------------------------------------------------
    -- Set the reservation 
    if bifi_lr_set = '1' then
      v.lr_valid := '1';
      --v.lr_addr := bifi_lr_addr(v.lr_addr'range);
      v.lr_addr := bifi_stdata(v.lr_addr'range);
    end if;
    -- Clear the reservation
    if bifi_lr_clr = '1' then
      v.lr_valid := '0';
    end if;
    -- Snooping
    -- NW FIXME: should this be added?  or r.ahb3_sntype=SNTYPE_RES1 then
    if r.ahb3_sntype=SNTYPE_SNOOP then
      --if r.ahb3_haddr(r.lr_addr'high downto DOFFSET_LOW) = 
      --   r.lr_addr(r.lr_addr'high downto DOFFSET_LOW) then
      if r.ahb3_haddr(31 downto DOFFSET_LOW) = 
         r.lr_addr(31 downto DOFFSET_LOW) then
        v.lr_valid := '0';
      end if;
    end if;
    

    --------------------------------------------------------------------------
    -- Snoop pipeline following AHB access/capture pipeline
    --------------------------------------------------------------------------

    -- AHB4 DCache tag update
    --   signal assignments at the bottom

    -- Read data from diagnostic snoop tag read
    -- set up regrddata unconditionally and just set
    -- regrddone when valid
    d64 := (others => '0');
    d64(DTAG_HIGH-2 downto DTAG_LOW) := r.ahb4_dtaguval(DTAG_HIGH-DTAG_LOW-1 downto 1);
    d64(DTAG_HIGH downto DTAG_HIGH-1) := r.ahb4_dtagumsb(1 downto 0);
    if r.ahb4_sntype(0)='1' then
      d64(63 downto 32) := d64(31 downto 0);
    end if;
    regrddata := d64;
    if r.ahb4_sntype=SNTYPE_STAGR or r.ahb4_sntype=SNTYPE_STAGRX then
      regrddone := '1';
    end if;

    -- AHB3 snoop tag compare

    v.ahb4_dtagupd  := (others => '0');
    v.ahb4_dtaguidx := r.ahb3_haddr(DOFFSET_HIGH downto DOFFSET_LOW);
    v.ahb4_dtaguval := r.ahb3_haddr(DTAG_HIGH-2 downto DTAG_LOW) & '0';
    v.ahb4_dtagumsb := r.ahb3_dtagumsb;
    v.ahb4_sntype := r.ahb3_sntype;
    v.ahb4_dtagutype := "00";
    if r.ahb3_sntype=SNTYPE_SNOOP or r.ahb3_sntype=SNTYPE_RES1 then
      for i in DWAYS-1 downto 0 loop
        vtag := dtagsdout(i)(DTAG_HIGH-DTAG_LOW+1 downto 1);
        if vtag=r.ahb3_haddr(DTAG_HIGH downto DTAG_LOW) and mapout(i)='1' then
          v.ahb4_dtagupd(i) := '1';
        end if;
      end loop;
    elsif r.ahb3_sntype=SNTYPE_FLUSH then
      v.ahb4_dtagutype := "01";
      v.ahb4_dtagupd := r.ahb3_waysel;
      v.ahb4_dtaguval := (others => '0');
      v.ahb4_dtaguval(DTAG_HIGH-DTAG_LOW-1 downto DTAG_HIGH-DTAG_LOW-6) := "110011";
      v.ahb4_dtagumsb := r.ahb3_dtagumsb;
    elsif r.ahb3_sntype=SNTYPE_DLFET then
      v.ahb4_dtagutype := "10";
      v.ahb4_dtagupd := bifi_dlfway;
      v.ahb4_dtaguval(0) := '1';
    elsif r.ahb3_sntype=SNTYPE_DTAGW then
      v.ahb4_dtagutype := "11";
      v.ahb4_dtagupd := r.ahb3_waysel;
      v.ahb4_dtaguval(0) := r.ahb3_haddr(0);
    elsif r.ahb3_sntype /= SNTYPE_SNOOP and r.ahb3_sntype /= SNTYPE_RES1 then
      -- Copy snoop tag output into dtaguval/dtagumsb for diagnostic
      -- snoop tag read
      for i in DWAYS-1 downto 0 loop
        if r.ahb3_waysel(i)='1' then
          vtag := dtagsdout(i)(DTAG_HIGH-DTAG_LOW+1 downto 1);
          v.ahb4_dtaguval := vtag(DTAG_HIGH-2 downto DTAG_LOW) & '0';
          v.ahb4_dtagumsb(1 downto 0) := vtag(DTAG_HIGH downto DTAG_HIGH-1);
        end if;
      end loop;
      v.ahb4_dtagupd := (others => '0');
    end if;

    -- AHB2 drive address into snoop RAM
    osni.dtagsindex(DOFFSET_BITS-1 downto 0) := r.ahb2_sindex;
    for w in 0 to DWAYS-1 loop
      osni.dtagsdin(w)(DTAG_HIGH-DTAG_LOW+1 downto 1) := r.ahb2_haddr(DTAG_HIGH downto DTAG_LOW);
    end loop;
    if r.ahb2_bifop(3)='0' then
      for w in 0 to DWAYS-1 loop
        osni.dtagsdin(w)(DTAG_HIGH-DTAG_LOW+1 downto 1) := r.ahb_hwdata(DTAG_HIGH downto DTAG_LOW);
      end loop;
    end if;

    v.ahb3_haddr := r.ahb2_haddr;
    v.ahb3_haddr(DOFFSET_HIGH downto DOFFSET_LOW) := r.ahb2_sindex;
    v.ahb3_sntype := SNTYPE_NONE;
    vdecway := (others => '0');
    if notx(r.ahb2_haddr) then
      vdecway(to_integer(unsigned(r.ahb2_haddr(DOFFSET_HIGH+2 downto DOFFSET_HIGH+1)))) := '1';
    else
      setx(vdecway);
    end if;
    v.ahb3_waysel := vdecway;
    for x in 0 to 3 loop
      v.ahb3_dtagumsb(2*x+1 downto 2*x) := r.ahb2_haddr(DTAG_HIGH downto DTAG_HIGH-1);
    end loop;
    if r.ahb2_bifop=BIFOP_DTAGW then
      for x in 0 to 3 loop
        v.ahb3_dtagumsb(2*x+1 downto 2*x) := r.ahb_hwdata(DTAG_HIGH downto DTAG_HIGH-1);
      end loop;
    end if;
    if r.ahb_phready='1' then
      if r.ahb2_htrans="10" and r.ahb2_hwrite='1' and r.ahb2_nosnoop='0' and bifi_snoopen='1' then
        -- Write snoop
        osni.dtagsen := (others => '1');
        v.ahb3_sntype := SNTYPE_SNOOP;
      elsif r.ahb2_htrans="10" and r.ahb2_bifop=BIFOP_DLFET then
        -- Tag update for DLine fetch
        osni.dtagsen := bifi_dlfway;
        osni.dtagswrite := '1';
        v.ahb3_sntype := SNTYPE_DLFET;
      elsif r.ahb2_bifop=BIFOP_STAGR or r.ahb2_bifop=BIFOP_STAGW or r.ahb2_bifop=BIFOP_STAGRX then
        -- Snoop tag diagnostic read or write
        osni.dtagsen := vdecway;
        osni.dtagswrite := not r.ahb2_bifop(0);
        if r.ahb2_bifop(0)='1' then
          if r.ahb2_bifop(2)='1' then
            v.ahb3_sntype := SNTYPE_STAGRX;
          else
            v.ahb3_sntype := SNTYPE_STAGR;
          end if;
        end if;
      elsif r.ahb2_bifop=BIFOP_DTAGW then
        -- DTag diagnostic write
        v.ahb3_sntype := SNTYPE_DTAGW;
        v.ahb3_haddr(DTAG_HIGH downto DTAG_LOW) := r.ahb_hwdata(DTAG_HIGH downto DTAG_LOW);
        v.ahb3_haddr(0) := r.ahb_hwdata(0);
      end if;
    end if;
    if r.ahb2_bifop=BIFOP_FLUSH or r.ahb2_bifop=BIFOP_FFLUSH then
      v.ahb3_waysel := r.ahb_hwdata(3 downto 0);
      v.ahb3_dtagumsb := r.ahb_hwdata(11 downto 4);
      osni.dtagsen := v.ahb3_waysel;
      osni.dtagswrite := '1';
      for w in 0 to DWAYS-1 loop
        osni.dtagsdin(w)(DTAG_HIGH-DTAG_LOW+1 downto 1) := (others => '0');
        osni.dtagsdin(w)(DTAG_HIGH-DTAG_LOW+1 downto DTAG_HIGH-DTAG_LOW) :=
          r.ahb_hwdata(4+w*2+1 downto 4+w*2);
      end loop;
      v.ahb3_sntype := SNTYPE_FLUSH;
    end if;

    --------------------------------------------------------------------------
    -- Internal register handling
    --------------------------------------------------------------------------
    -- IR2 internal register read/write
    if r.ir2_bifop=BIFOP_DPASS then
      regrddone := '1';
      regrddata := r.ahb_hwdata(63 downto 0);
    elsif r.ir2_bifop=BIFOP_AREGR then
      regrddone := '1';
      -- Note bit 7 of the address is checked here to distinguish ASI 2 register
      -- offset 0x20/24 and 0xA0/0xA4
      if r.ir2_haddr(7)='0' then
        -- status and 32-bit error address registers
        d32 := (others => '0');
        -- bits 31:28 passed through from store data
        d32(          27) := r.icignerr;
        d32(          26) := r.dcerrmaskval;
        d32(          25) := r.dcerrmask;
        d32(          24) := r.dcignerr;
        d32(20 downto 16) := r.ahberracc;
        d32(          15) := r.ahberrhwrite;
        d32(14 downto 11) := r.ahberrhmaster;
        d32(10 downto  8) := r.ahberrhsize;
        d32( 5 downto  4) := r.ahberrtype;
        d32( 3 downto  0) := r.ahboerrm & r.ahberrm & r.ahboerr & r.ahberr;
        if endian='0' then
          regrddata := d32 & r.ahberrhaddr(31 downto 0);
          regrddata(63 downto 60) := r.ahb_hwdata(63 downto 60);
        else
          regrddata := r.ahberrhaddr(31 downto 0) & d32;
          regrddata(31 downto 28) := r.ahb_hwdata(31 downto 28);
        end if;
      else
        -- 64-bit error address register
        regrddata := (others => '0');
        regrddata(abitsi-1 downto 0) := r.ahberrhaddr;
      end if;
    elsif r.ir2_bifop=BIFOP_AREGW then
      d32 := r.ahb_hwdata(31 downto 0);
      if endian='0' then
        d32 := r.ahb_hwdata(63 downto 32);
      end if;
      if (r.ir2_wmask(1)='1' and endian='0') or (r.ir2_wmask(0)='1' and endian='1') then
        v.icignerr     := d32(27);
        v.dcerrmaskval := d32(26);
        v.dcerrmask    := d32(25);
        v.dcignerr     := d32(24);
        if d32(3)='1' then v.ahboerrm := '0'; end if;
        if d32(2)='1' then v.ahberrm  := '0'; end if;
        if d32(1)='1' then v.ahboerr  := '0'; end if;
        if d32(0)='1' then v.ahberr   := '0'; end if;
      end if;
    end if;

    v.regrd := regrddone;
    v.regrddata := regrddata;
    v.regrderr := '0';

    --------------------------------------------------------------------------
    -- AHB access logic
    --------------------------------------------------------------------------
    for x in ibusw/32-1 downto 0 loop
      bufdata(x*32+31 downto x*32) := ahbi_hrdata( ((32*x) mod rbusw)+31 downto ((32*x) mod rbusw) );
    end loop;

    -- AHB1 data phase

    masktrans := '0';

    v.ahb_phready := ahbi_hready;
    v.ahb3_wcombdone := "00";
    -- Capture anoop access but forward our data instead if there is no
    -- access (to allow diagnostic accesses to be handled with same logic)
    if ahbi_hready='1' then
      if ahbsi_htrans(1)='0' then
        v.ahb2_haddr := (others => '0');
        v.ahb2_haddr(abitso-1 downto 0) := r.ahb_haddr;
        v.ahb2_hwrite := r.ahb_hwrite;
        v.ahb2_hsize := r.ahb_hsize;
      else
        v.ahb2_haddr := ahbsi_haddr(abitsi-1 downto 0);
        v.ahb2_hwrite := ahbsi_hwrite;
        v.ahb2_hsize := ahbsi_hsize;
      end if;
      v.ahb2_hmaster := ahbsi_hmaster;
      v.ahb2_htrans := ahbsi_htrans;
      v.granted := ahbi_hgrant;
      if r.granted='1' then
        v.ahb2_nosnoop := r.ahb_nosnoop;
        v.ahb2_hlock := r.ahb_hlock;
      else
        v.ahb2_nosnoop := '0';
        v.ahb2_hlock := '0';
      end if;
    end if;
    -- Read data from diagnostic snoop tag read, pass through or register read
    if r.regrd='1' then
      bsetdone := '1';
      bsetvalid := (others => '1');
      d64 := r.regrddata;
      for x in ibusw/64-1 downto 0 loop
        bufdata(x*64+63 downto x*64) := d64;
      end loop;
      if r.regrderr='1' then
        bseterror := (others => '1');
      end if;
    end if;
    -- Error masking for data and instruction loads
    if r.ahb2_inacc='1' then
      if r.ahb2_bifop(1 downto 0)="11" or (r.dcerrmask='1' and r.dcerrmaskval='0') then
        oerrclr(0) := '1';
      elsif r.dcerrmask='1' then
        oerrclr(1) := '1';
      end if;
    end if;
    -- Ensure that burstctra is cleared when we are standing with accfa
    -- pointing to the next access to be written. Otherwise the burstctra bits
    -- may get masked depending on what access is currently in the FIFO.
    if r.accfw=r.accfa and r.bifready/='0' then
      v.burstctra := (others => '0');
    end if;
    if ahbi_hready='1' or (r.ahb2_inacc='0' and r.ahb_bifop=BIFOP_FFLUSH) then
      -- Capture read data
      if r.ahb2_inacc='1' and r.ahb2_hwrite='0' and r.ahb2_last='1' then
        bsetdone := '1';
      end if;
      if r.ahb2_inacc='1' then
        bsetvalid := r.ahb2_addrmask;
      end if;
      -- The access that is in address phase this cycle is data phase following
      v.accfd := r.accfa;

      if r.ahb2_inacc='1' and r.ahb2_last='1' and r.ahb2_wcomb(0)='1' then
        -- Wind up address counter after write-combining burst
        -- This is designed with masktrans condition to always happen
        -- when there is no access going out so code below that
        -- increments/decrements can use r.accfa
        v.accfa := add(r.accfa, r.ahb2_wcomb);
        v.accfd := v.accfa;
        v.burstctra := (others => '0');
        v.bifready := '1';
      end if;

      v.ahb2_sindex := v.ahb2_haddr(DOFFSET_HIGH downto DOFFSET_LOW);

      v.ahb2_inacc := r.granted and r.ahb_htrans(1);

      -- "virtual" access in data phase (access that does not actually
      -- generate an AHB access)
      v.ahb2_indiag := '0';
      if ahbsi_htrans(1)='0' and r.ahb_bifop(3 downto 2)/="10" and r.ahb_bifop(1 downto 0)/="00" then
        v.ahb2_indiag := '1';
      end if;
      -- Special case for flushing whole cache, we allow the diagnostic
      -- access through even if there is a  regular  access by another
      -- master at the same time. We don't really care about snooping
      -- the other access in this case since the entire cache is flushed
      -- anyway. This also makes flush time independent of AHB traffic.
      -- Note that we have a separate register for the sindex to allow
      -- capturing the data for an AHB error happening at the same time.
      if r.ahb_bifop=BIFOP_FFLUSH then
        v.ahb2_indiag := '1';
        v.ahb2_sindex := r.ahb_haddr(DOFFSET_HIGH downto DOFFSET_LOW);
      end if;

      if v.ahb2_inacc='1' or v.ahb2_indiag='1' then
        v.ahb2_bifop := r.ahb_bifop;
        v.ahb2_wcomb := r.ahb_wcomb;
        if r.ahb_wcomb(0)='0' then v.ahb2_wcomb := "00"; end if;
      else
        v.ahb2_bifop := BIFOP_NOP;
        v.ahb2_wcomb := "00";
      end if;

      if r.ahb_hwrite='0' and v.ahb2_inacc='1' then
        bsetstarted := '1';
        v.ahb2_addrmask := getvalidmask(r.ahb_haddr(5 downto 2), r.ahb_hsize, r.ahb_bifop, endian, dlinesize, ilinesize, rbusw);
      else
        v.ahb2_addrmask := (others => '0');
      end if;
      if (v.ahb2_inacc='1' or v.ahb2_indiag='1') then
        v.ahb2_last := '0';
        if r.burstctra=(r.burstctra'range => '1') then
          v.ahb2_last := '1';
        end if;
      end if;

      if v.ahb2_inacc='1' or v.ahb2_indiag='1' then
        v.burstctra := add(r.burstctra, 1);
        -- Are we at end of burst and should advance to next access
        if r.burstctra=(r.burstctra'range => '1') then
          v.burstctra := (others => '0');
          v.accfa := add(r.accfa, 1);
        end if;
      end if;

    elsif ahbi_hresp(1)='1' and r.ahb2_inacc='1' then
      -- Rewind address phase counter for retry/split
      v.ahb2_inacc := '0'; -- prevent read data valid update
      v.burstctra := sub(r.burstctra, 1);
      -- Note checking burstctra for 0 here isn't valid due to
      -- higher bits forced to high
      if r.ahb2_last='1' then
        v.accfa := sub(r.accfa,1);
        v.burstctra := (others => '1');
      end if;
      masktrans := '1';

    elsif ahbi_hresp(0)='1' and r.ahb2_inacc='1' then
      -- Error response
      -- For read data, we adjust the rdbufe vector.
      -- If we have enabled error masking we also clear ahb2_addrmask to
      -- avoid copying in the data into the buffer. The error mask logic
      -- will fill in data based on rdbufe instead
      bseterror := r.ahb2_addrmask;
      v.ahb2_addrmask := (others => '0');
    end if;

    -- AHB access capture for error status register
    if ahbi_hready='1' then
      if r.ahb2_htrans(0)='0' then v.errburstfilt := '0'; end if;
      if ahbi_hresp="01" then
        -- Ensure we only capture one error response per burst
        v.errburstfilt := '1';
        if r.ahb2_htrans(0)='0' or r.errburstfilt='0' then
          if r.ahb2_inacc='1' then
            -- our access got error response
            v.ahberr := '1';
            if r.ahberr='1' then
              v.ahberrm := '1';
            end if;
            if r.ahb2_bifop(1 downto 0)="10" then
              -- DLine fetch
              v.ahberracc(1) := '1';
            elsif r.ahb2_bifop(1 downto 0)="11" then
              -- ILine fetch
              v.ahberracc(0) := '1';
            elsif r.ahb2_bifop(0)='0' then
              if r.ahb_mmuacc='0' then
                -- regular store
                v.ahberracc(2) := '1';
              else
                -- mmu PTE writeback
                v.ahberracc(4) := '1';
              end if;
            else
              if r.ahb_mmuacc='0' then
                -- regular load
                v.ahberracc(1) := '1';
              else
                -- mmu page table walk load
                v.ahberracc(3) := '1';
              end if;
            end if;
          else
            -- other master's access got error response
            v.ahboerr := '1';
            if r.ahboerr='1' then
              v.ahboerrm := '1';
            end if;
          end if;
        end if;
      end if;
    end if;
    -- update ahberrtype so that it locks to the right value
    -- when v.ahberr changes to 1 above
    if r.ahberr='0' then
      if r.ahb2_bifop(1 downto 0)="11" then
        v.ahberrtype := "00";
      elsif r.ahb_mmuacc='1' then
        v.ahberrtype := "10";
      else
        v.ahberrtype := "01";
      end if;
    end if;
    if (v.ahberr='1' and r.ahberr='0') or (r.ahberr='0' and r.ahboerr='0') then
      v.ahberrhaddr := r.ahb2_haddr;
      v.ahberrhwrite := r.ahb2_hwrite;
      v.ahberrhsize := r.ahb2_hsize;
      v.ahberrhmaster := r.ahb2_hmaster;
    end if;
    --  Store error signaling to cache controller
    vwmcur := '0';
    if notx(r.accfd) then
      dfent := r.accfifo(to_integer(unsigned(r.accfd)));
    else
      setx(dfent);
    end if;
    vwmcur := dfent.errmask;
    v.sterr := (others => '0');
    if ahbi_hready='1' and ahbi_hresp="01" and r.ahb2_inacc='1' and r.ahb2_bifop=BIFOP_STORE then
      if r.ahb_mmuacc='0' then
        if vwmcur='1' or bifi_maskwerr(0)='1' then
          v.sterr(2) := '1';
        else
          v.sterr(0) := '1';
        end if;
      else
        if vwmcur='1' or bifi_maskwerr(1)='1' then
          v.sterr(3) := '1';
        else
          v.sterr(1) := '1';
        end if;
      end if;
    end if;


    -- IR1 data phase
    -- Special handling for dpass,aregw,aregn commands that do not access AMBA
    -- bus or snoop/cache tags. We only have them in the address phase for one
    -- cycle regardless of AMBA bus status. Instead moved to ir2_* registers
    -- We block this while inside an access to avoid colliding with retry handling
    --   and overwriting the hwdata registers
    virready := ahbi_hready and v.ahb2_indiag;
    if r.ahb_bifop=BIFOP_FFLUSH then virready := '1'; end if;
    if (r.accfw/=r.accfa or r.bifready='0') and (r.ahb_bifop=BIFOP_DPASS or r.ahb_bifop=BIFOP_AREGW or r.ahb_bifop=BIFOP_AREGR) then
      if r.accfa=r.accfd then
        virready := '1';
        v.burstctra := (others => '0');
        v.accfa := add(r.accfa, 1);
        v.accfd := add(r.accfd, 1);
      end if;
    end if;
    v.ir2_bifop := BIFOP_NOP;
    v.ir2_haddr := r.ahb_haddr(7 downto 7);
    v.ir2_wmask := "00";
    if r.ahb_hsize(1)='1' then
      v.ir2_wmask := "11";
    end if;
    if r.ahb_haddr(2)='0' xor endian='1' then
      v.ir2_wmask(1) := '1';
    else
      v.ir2_wmask(0) := '1';
    end if;
    if virready='1' then
      v.ir2_bifop := r.ahb_bifop;
    end if;

    -- AHB0 address phase

    -- Handle errmask before nfent assignment to new entry
    for x in v.accfifo'range loop
      if (bifi_maskwerr(0)='1' and r.accfifo(x).mmuacc='0') or (bifi_maskwerr(1)='1' and r.accfifo(x).mmuacc='1') then
        v.accfifo(x).errmask := '1';
      end if;
    end loop;

    nfent := (
      bifop    => bifi_bifop,
      addr     => bifi_busaddr,
      size     => bifi_size,
      data     => bifi_stdata,
      nosnoop  => bifi_nosnoop,
      widebus  => bifi_widebus,
      su       => bifi_su,
      mmuacc   => bifi_mmuacc,
      errmask  => '0',
      wcomb    => '0' & bifi_wcomb,
      wcblen   => "00",
      lock     => r.lockstate
      );
    if r.bifready='1' then
      v.accfifo(to_integer(unsigned(r.accfw))) := nfent;
      -- We insert any operations that are not NOP or LOCK into the FIFO
      if bifi_bifop(3)='1' or bifi_bifop(1 downto 0)/="00" then
        v.accfw := add(r.accfw, 1);
        if v.accfw=v.accfd then v.bifready := '0'; end if;
      end if;
    elsif v.accfd /= r.accfw then
      v.bifready := '1';
    end if;
    if bifi_bifop=BIFOP_NOP or bifi_bifop=BIFOP_LOCK then
      v.lockstate := bifi_bifop(2);
    end if;
    -- Special signal used by striped busif in order to manage holding
    -- off stores in the middle of atomic sequence
    if keeplock/='0' then
      v.lockstate := r.lockstate;
    end if;

    if notx(v.accfa) then
      afent := v.accfifo(to_integer(unsigned(v.accfa)));
    else
      setx(afent);
    end if;
    v.ahb_bifop := BIFOP_NOP;
    if (v.accfw/=v.accfa or v.bifready='0') then
      v.ahb_bifop := afent.bifop;
    end if;
    v.ahb_htrans := "00";
    if afent.bifop(3 downto 2)="10" and (v.accfw/=v.accfa or v.bifready='0') then
      v.ahb_htrans(1) := '1';
      if v.ahb2_inacc='1' and v.ahb2_last='0' then
        v.ahb_htrans(0) := '1';
      end if;
    end if;
    v.ahb_hwrite := '0';
    if afent.bifop(1 downto 0)="00" then
      v.ahb_hwrite := '1';
    end if;
    v.ahb_wcomb(0) := afent.wcomb(1);
    -- Set ahb_wcomb to "01" for 2-entry and "11" for 4-entry
    if (afent.widebus='1' and busw=128) then
      v.ahb_wcomb(1) := afent.wcblen(0);
    elsif (afent.widebus='1' and busw=64) then
      v.ahb_wcomb(1) := not afent.wcblen(0);
    else
      v.ahb_wcomb(1) := afent.wcblen(0);
    end if;
    if afent.lock /= r.ahb_hlock or r.ahb_hlock /= r.ahb2_hlock then
      masktrans := '1';
    end if;
    if afent.wcomb="01" then
      masktrans := '1';
    end if;
    if v.ahb2_inacc='1' and v.ahb2_last='1' and v.ahb2_wcomb(0)='1' then
      -- Mask access this cycle as we will change the counters to
      --   skip ahead of entries there were write-combined
      masktrans := '1';
    end if;
    if masktrans='1' then v.ahb_htrans := "00"; v.ahb_bifop := BIFOP_NOP; end if;
    v.ahb_haddr := afent.addr;
    bctrmask := (others => '1');
    if afent.wcomb(1)='1' then
      if (afent.widebus='1' and busw=64) then
        -- Write combining burst to wide area, 64-bit bus
        v.ahb_hsize := std_logic_vector(to_unsigned(log2(busw/8),3));
        -- wcblen=10 or wcblen=01 possible here
        if afent.wcblen(1)='1' then
          v.ahb_haddr(DLINE_LOW_W+1 downto DLINE_LOW_W) := v.burstctra(1 downto 0);
        else
          v.ahb_haddr(DLINE_LOW_W) := v.burstctra(0);
        end if;
      elsif afent.widebus='1' then
          -- Write combining burst to wide area, 128-bit bus
        v.ahb_hsize := std_logic_vector(to_unsigned(log2(busw/8),3));
        -- wcblen=01 or wcblen=00 possible here
        if afent.wcblen(0)='1' then
          v.ahb_haddr(DLINE_LOW_W) := v.burstctra(0);
        end if;
      else
        -- Write combining burst to narrow area
        v.ahb_hsize := "010";
        -- wcblen=10 or wcblen=11 possible here
        if afent.wcblen(0)='1' then
          v.ahb_haddr(4 downto 2) := v.burstctra(2 downto 0);
        else
          v.ahb_haddr(3 downto 2) := v.burstctra(1 downto 0);
        end if;
      end if;
      case afent.wcblen is
        when "11" => bctrmask(2 downto 0) := "000";
        when "10" => bctrmask(1 downto 0) := "00";
        when "01" => bctrmask(0) := '0';
        when others => null;
      end case;
      if afent.wcblen /= "00" then
        v.ahb_hburst := HBURST_INCR;
      else
        v.ahb_hburst := HBURST_SINGLE;
      end if;
    elsif afent.bifop(1)='1' then
      if (afent.widebus='1' and busw>32) then
        v.ahb_hsize := std_logic_vector(to_unsigned(log2(busw/8),3));
        if afent.bifop(0)='0' then
          -- DLine fetch from wide area
          v.ahb_haddr(DLINE_HIGH downto DLINE_LOW_W) := v.burstctra(DLINE_HIGH-DLINE_LOW_W downto 0);
          v.ahb_haddr(DLINE_LOW_W-1 downto 0) := (others => '0');
          bctrmask(DLINE_HIGH-DLINE_LOW_W downto 0) := (others => '0');
        else
          -- ILine fetch from wide area
          v.ahb_haddr(ILINE_HIGH downto ILINE_LOW_W) := v.burstctra(ILINE_HIGH-ILINE_LOW_W downto 0);
          v.ahb_haddr(ILINE_LOW_W-1 downto 0) := (others => '0');
          bctrmask(ILINE_HIGH-ILINE_LOW_W downto 0) := (others => '0');
        end if;
      else
        v.ahb_hsize := "010";
        if afent.bifop(0)='0' then
          -- DLine fetch from narrow area
          v.ahb_haddr(DLINE_HIGH downto 2) := v.burstctra(DLINE_HIGH-2 downto 0);
          bctrmask(DLINE_HIGH-2 downto 0) := (others => '0');
        else
          -- ILine fetch from narrow area
          v.ahb_haddr(ILINE_HIGH downto 2) := v.burstctra(ILINE_HIGH-2 downto 0);
          bctrmask(ILINE_HIGH-2 downto 0) := (others => '0');
        end if;
      end if;
      v.ahb_hburst := HBURST_INCR;
    else
      if (afent.widebus='1' and busw>32) or afent.size/="11" then
        --   Single access size<64 bits or size=64 bits and wide bus
        v.ahb_hsize := "0" & afent.size;
        v.ahb_hburst := HBURST_SINGLE;
      else
        --   Single access size=64 bits and narrow bus
        v.ahb_hsize := "010";
        v.ahb_hburst := HBURST_INCR;
        v.ahb_haddr(2) := v.burstctra(0);
        bctrmask(0) := '0';
      end if;
    end if;
    -- Silence AHB monitor by ensuring haddr is aligned to hsize even when htrans=0
    if v.ahb_htrans(1)='0' then
      v.ahb_haddr(log2(busw/8)-1 downto 0) := (others => '0');
      v.ahb_haddr(3 downto 0) := (others => '0');
    end if;
    if afent.bifop(3 downto 2)/="10" then bctrmask := (others => '1'); end if;
    v.ahb_hprot := "1101";
    if afent.bifop(1 downto 0)="11" then v.ahb_hprot(0) := '0'; end if;
    if afent.su='1' and afent.mmuacc='0' then v.ahb_hprot(1) := '1'; end if;
    v.ahb_nosnoop := afent.nosnoop;
    -- Ensure unused high bits of burstctra are one so counter wraps to zero
    -- after last access.
    v.burstctra := v.burstctra or bctrmask;

    -- hwdata generation
    -- Instead of using v.accfd we use ahbi_hready and r.accfa/r.burstctra to
    -- determine data to drive and let output register hold the data otherwise
    -- Get current entry to generate next hwdata from
    if notx(r.accfa) then
      dfent := r.accfifo(to_integer(unsigned(r.accfa)));
    else
      setx(dfent);
    end if;
    -- Burst counter masked for write combining logic
    vctra := r.burstctra(2 downto 0);
    case dfent.wcblen is
      when "00" => vctra := "000";
      when "01" => vctra(2 downto 1) := "00";
      when "10" => vctra(2) := '0';
      when others => null;
    end case;
    -- Compute vector with 3 bits for each 32-bit output word, 2 bits to select
    --   FIFO entry, and 1 bit to select high or low 32-bit word
    datasel := (others => '0');
    for x in 0 to busw/32-1 loop
      vinc := "00";
      if dfent.wcomb(1)='1' then
        if (dfent.widebus='0' or busw<64) then
          -- increment FIFO sel based on burstctra bits 2:1
          vinc := vctra(2 downto 1);
        elsif busw=64 then
          -- increment FIFO sel based on burstctra 1:0
          vinc := vctra(1 downto 0);
        else
          -- increment FIFO sel x2 based on burstctra 0 and x1 internal pos
          vinc(1) := vctra(0);
          if (endian='1' and x>1) or
            (endian='0' and busw>64 and x<2) then
            vinc(0) := '1';
          end if;
        end if;
      end if;
      vsel64 := std_logic_vector(unsigned(r.accfa)+unsigned(vinc));
      vsel32 := '0';
      if (dfent.widebus='0' or busw<64) and dfent.size="11" then
        vsel32 := (not r.burstctra(0)) xor endian;
      elsif ((x mod 2) = 1) then
        vsel32 := '1';
      end if;
      datasel(3*x+2 downto 3*x) := vsel64 & vsel32;
    end loop;
    -- Update hwdata when hready=1
    if ahbi_hready='1' or virready='1' then
      for x in 0 to busw/32-1 loop
        ventsel := datasel(3*x+2 downto 3*x+1);
        if notx(ventsel) then
          vent1 := r.accfifo(to_integer(unsigned(ventsel)));
        else
          setx(vent1);
        end if;
        if datasel(3*x)='0' then
          v.ahb_hwdata(x*32+31 downto x*32) := vent1.data(31 downto 0);
        else
          v.ahb_hwdata(x*32+31 downto x*32) := vent1.data(63 downto 32);
        end if;
      end loop;
    end if;
    -- special case for pass-through/aregw when busw=32
    if busw=32 then
      v.ahb_hwdata(63 downto 32) := dfent.data(63 downto 32);
    end if;
    if ahbi_hready='1' then
      v.ahb_mmuacc := dfent.mmuacc;
    end if;

    -- Toggle lock status
    -- Note afent.lock has valid value even if no operation is being enqueued
    if r.accfd=r.accfa and afent.lock/=r.ahb_hlock then
      v.ahb_hlock := not r.ahb_hlock;
    end if;

    -- Bus request handling
    keepreq := '1';
    if add(r.accfa,1)=v.accfw and v.burstctra=(v.burstctra'range => '1') then
      keepreq := '0';
    end if;
    v.ahb_hbusreq := '0';
    if (v.ahb_htrans(1)='1') and (v.granted='0' or keepreq='1') then
      v.ahb_hbusreq := '1';
    end if;
    if v.ahb_hlock='1' then
      v.ahb_hbusreq := '1';
    end if;

    -- Logic to detect livelock situations where AHB is flooded with stores
    -- and raise bus request to create a time slot for the diagnostic
    -- access.
    if r.granted='0' and r.ahb_bifop(1 downto 0)/="00" and (r.accfw/=r.accfa or r.bifready='0') then
      if r.llctr /= (r.llctr'range => '1') then
        v.llctr := add(r.llctr,1);
      else
        v.ahb_hbusreq := '1';
      end if;
    else
      v.llctr := (others => '0');
    end if;

    -- Idle flag - note we allow for regular snoops from other masters to be in progress
    -- even if idle is flagged.
    v.bifidle := '0';
    if r.accfw=r.accfd and r.bifready='1' then
      v.bifidle := '1';
    end if;
    if bifi_bifop /= BIFOP_NOP and bifi_bifop /= BIFOP_LOCK then
      v.bifidle := '0';
    end if;
    if r.ahb3_sntype /= SNTYPE_NONE and r.ahb3_sntype /= SNTYPE_SNOOP then
      v.bifidle := '0';
    end if;

    -- Locked and all snoops completed flag
    v.biflocked := '0';
    if r.lockstate='1' and r.ahb_hlock='1' and r.granted='1' and
      r.ahb2_hlock='1' and r.ahb3_sntype=SNTYPE_NONE then
      v.biflocked := '1';
    end if;

    -- Transfer pending flag generation
    v.stpend := "00";
    -- Generate mask of which FIFO entries have not yet been in address/data phase
    -- by the next cycle
    spunseena := (others => '0');
    if notx(v.accfw) and notx(v.accfa) then
      for x in 0 to 3 loop
        -- We first assume the next access in v.accfa will not been in address
        -- phase (because we have not been granted) and handle it below
        if unsigned(v.accfw) > unsigned(v.accfa) and unsigned(v.accfa) <= x and unsigned(v.accfw) > x then
          spunseena(x) := '1';
        end if;
        if unsigned(v.accfw) < unsigned(v.accfa) and (unsigned(v.accfa) <= x or unsigned(v.accfw) > x) then
          spunseena(x) := '1';
        end if;
        if v.accfw=v.accfa and r.bifready='0' then
          spunseena(x) := '1';
        end if;
        -- Handle if current access and following cycle's access has been
        -- granted
        if (v.accfw/=v.accfa or v.bifready='0') and v.accfa=std_logic_vector(to_unsigned(x,2)) and v.granted='1' then
          spunseena(x) := '0';
        end if;
      end loop;
    else
      setx(spunseena);
    end if;
    spunseend := (others => '0');
    if notx(v.accfd) and notx(v.accfw) then
      for x in 0 to 3 loop
        if v.accfd=v.accfw and v.bifready='0' then spunseend(x) := '1'; end if;
        if unsigned(v.accfw) > unsigned(v.accfd) and unsigned(v.accfd) <= x and unsigned(v.accfw) > x then
          spunseend(x) := '1';
        end if;
        if unsigned(v.accfw) < unsigned(v.accfd) and (unsigned(v.accfd) <= x or unsigned(v.accfw) > x) then
          spunseend(x) := '1';
        end if;
      end loop;
    else
      setx(spunseend);
    end if;
    for x in 0 to 3 loop
      if spunseena(x)='1' and v.accfifo(x).bifop=BIFOP_STORE then
        v.stpend(0) := '1';
      end if;
      if spunseend(x)='1' and v.accfifo(x).bifop=BIFOP_STORE then
        v.stpend(1) := '1';
      end if;
    end loop;

    --------------------------------------------------------------------------
    -- Write combining
    --------------------------------------------------------------------------
    -- Create mask of which FIFO entries are valid
    -- This includes the entry that is currently in address phase (but if it's
    --   potentially write combinable it's blocked from proceeding) but not
    --   the entry (if one) in the data phase.
    wcentvalid := "0000";
    if notx(r.accfw) and notx(r.accfa) then
      for x in 0 to 3 loop
        if r.bifready='0' and r.accfw=r.accfa then
          wcentvalid(x) := '1';
        else
          if unsigned(r.accfw) > unsigned(r.accfa) and unsigned(r.accfa) <= x and unsigned(r.accfw) > x then
            wcentvalid(x) := '1';
          end if;
          if unsigned(r.accfw) < unsigned(r.accfa) and (unsigned(r.accfa) <= x or unsigned(r.accfw) > x) then
            wcentvalid(x) := '1';
          end if;
        end if;
      end loop;
    else
      setx(wcentvalid);
    end if;
    -- Create mask of which entries have a valid following entry
    wcnextvalid := wcentvalid(1 to 3) & wcentvalid(0);
    -- avoid checking for write combining across wrapping point when store buffer
    -- is full.
    for x in 0 to 3 loop
      if r.accfd=std_logic_vector(to_unsigned((x+1) mod 4,2)) then
        wcnextvalid(x) := '0';
      end if;
    end loop;
    -- Create mask of entries that can *not* be write combined and
    --   mask of entries that can join with following access
    wckmask := "0000";
    wcbmask := "0000";
    for x in 0 to 3 loop
      vent1 := r.accfifo(x);
      vent2 := r.accfifo((x+1) mod 4);
      if wcentvalid(x)='1' and wcnextvalid(x)='1' then
        if vent1.bifop=BIFOP_STORE and vent2.bifop=BIFOP_STORE and
          vent1.size="11" and vent2.size="11" and
          vent1.addr(31 downto 5)=vent2.addr(31 downto 5) and
          vent1.su=vent2.su and
          vent1.addr(4 downto 3)/="11" and
          add(vent1.addr(4 downto 3),1)=vent2.addr(4 downto 3) and
          vent1.nosnoop=vent2.nosnoop then
          wcbmask(x) := '1';
        else
          wckmask(x) := '1';
        end if;
      end if;
      if wcentvalid(x)='1' and not (vent1.bifop=BIFOP_STORE and vent1.size="11" and vent1.wcomb(0)='1') then
        wckmask(x) := '1';
      end if;
    end loop;
    -- Clear write combine mask for entries that have wckmask set
    for x in 0 to 3 loop
      if wckmask(x)='1' then
        v.accfifo(x).wcomb := "00";
      end if;
    end loop;
    -- Check if we have a write combining burst starting on the next entry to
    -- go out
    wctimeout := '0';
    if r.wctoctr=(r.wctoctr'range => '1') then wctimeout := '1'; end if;
    v.wctoctr := (others => '0');
    if r.accfd=r.accfa then
      for x in 0 to 3 loop
        vent1 := r.accfifo(x);
        if r.accfa=std_logic_vector(to_unsigned(x,2)) and vent1.wcomb(1 downto 0)="01" then
          if r.wctoctr /= (r.wctoctr'range => '1') then
            v.wctoctr := add(r.wctoctr,1);
          end if;
          if wcbmask(x)='1' and wcbmask((x+1) mod 4)='1' and wcbmask((x+2) mod 4)='1' and vent1.addr(4 downto 3)="00" then
            -- 64-byte / 256-bit burst  (8x32 / 4x64 / 2x128)
            v.accfifo(x).wcomb(1) := '1';
            if r.accfifo(x).widebus='1' and busw>32 then
              if busw>64 then
                v.accfifo(x).wcblen := "01";
              else
                v.accfifo(x).wcblen := "10";
              end if;
            else
              v.accfifo(x).wcblen := "11";
            end if;
            v.burstctra := (others => '0');
          elsif wcbmask(x)='1' and (wckmask((x+1) mod 4)='1' or wckmask((x+2) mod 4)='1' or wctimeout='1' or vent1.addr(4)='1') and vent1.addr(3)='0' then
            -- 32-byte / 128-bit burst (4x32 / 2x64 / 1x128)
            v.accfifo(x).wcomb(1) := '1';
            if r.accfifo(x).widebus='1' and busw>32 then
              if busw>64 then
                v.accfifo(x).wcblen := "00";
              else
                v.accfifo(x).wcblen := "01";
              end if;
            else
              v.accfifo(x).wcblen := "10";
            end if;
            v.burstctra := (others => '0');
          elsif vent1.addr(3)='1' or wctimeout='1' then
            v.accfifo(x).wcomb(0) := '0';
          end if;
        end if;
      end loop;
    end if;

    -- Reset
    if ( GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 and
         GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all)=0 ) then
      if rstn='0' then
        v.ahb_hbusreq := RRES.ahb_hbusreq;
        v.ahb_hlock   := RRES.ahb_hlock;
        v.ahb_htrans  := RRES.ahb_htrans;
        v.ahb_bifop   := RRES.ahb_bifop;
        v.bifready    := RRES.bifready;
        v.accfw       := RRES.accfw;
        v.accfa       := RRES.accfa;
        v.accfd       := RRES.accfd;
        v.icignerr    := RRES.icignerr;
        v.dcignerr    := RRES.dcignerr;
        v.dcerrmask   := RRES.dcerrmask;
        v.dcerrmaskval:= RRES.dcerrmaskval;
        v.lr_valid    := RRES.lr_valid;
      end if;
    end if;

    nr <= v;
    ahbo_hbusreq <= r.ahb_hbusreq;
    ahbo_hlock   <= r.ahb_hlock;
    ahbo_htrans  <= r.ahb_htrans;
    ahbo_haddr   <= (others => '0');
    ahbo_haddr(abitso-1 downto 0) <= r.ahb_haddr;
    ahbo_hwrite  <= r.ahb_hwrite;
    ahbo_hsize   <= r.ahb_hsize;
    ahbo_hburst  <= r.ahb_hburst(hburstw-1 downto 0);
    ahbo_hprot   <= r.ahb_hprot;
    for x in 0 to sigbusw/busw-1 loop
      ahbo_hwdata((x+1)*busw-1 downto x*busw)  <= r.ahb_hwdata(busw-1 downto 0);
    end loop;
    rdbufw       <= bsetvalid;
    rdbufwd      <= (others => '0');
    for x in 1 downto 0 loop
      rdbufwd(x*64+63 downto x*64) <= bufdata(((x*64) mod ibusw)+63 downto ((x*64) mod ibusw));
    end loop;
    rdbufe       <= bseterror;
    nrddone      <= bsetdone;
    nrdstarted   <= bsetstarted;
    errclr       <= oerrclr;
    bifo_ready   <= r.bifready;
    bifo_idle    <= r.bifidle;
    bifo_sterr   <= r.sterr;
    bifo_locked  <= r.biflocked;
    bifo_dtagupd <= r.ahb4_dtagupd;
    bifo_dtaguidx    <= (others => '0');
    bifo_dtaguidx(DOFFSET_BITS-1 downto 0)       <= r.ahb4_dtaguidx;
    bifo_dtaguval    <= (others => '0');
    bifo_dtaguval(DTAG_HIGH-DTAG_LOW-1 downto 0) <= r.ahb4_dtaguval;
    bifo_dtagumsb    <= r.ahb4_dtagumsb;
    bifo_dtagutype   <= r.ahb4_dtagutype;
    -- NW FIXME: added for NV atomic operations
    bifo_lr_valid    <= r.lr_valid;
    bifo_stpend  <= r.stpend;
    dtagsindex   <= osni.dtagsindex;
    dtagsen      <= osni.dtagsen;
    dtagswrite   <= osni.dtagswrite;
    dtagsdin     <= osni.dtagsdin;
    maprindex    <= (others => '0');
    maprindex(DOFFSET_BITS-1 downto 0)   <= r.ahb3_haddr(DOFFSET_HIGH downto DOFFSET_LOW);
  end process;

  srstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)=0 generate
    regs: process(clk)
    begin
      if rising_edge(clk) then
        r <= nr;
        if GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) /= 0 and rstn='0' then
          r <= RRES;
        end if;
      end if;
    end process;
  end generate;

  arstregs: if GRLIB_CONFIG_ARRAY(grlib_async_reset_enable)/=0 generate
    regs: process(clk,rstn)
    begin
      if rstn='0' then
        r <= RRES;
      elsif rising_edge(clk) then
        r <= nr;
      end if;
    end process;
  end generate;

--pragma translate_off
  biftrace_gen: if biftrace_en generate
    p: process(clk)
      function bifopname(op: std_logic_vector) return string is
        variable xop: std_logic_vector(3 downto 0);
      begin
        xop := op;
        case xop is
          when BIFOP_NOP    => return "NOP   ";
          when BIFOP_DTAGW  => return "DTAGW ";
          when BIFOP_STAGR  => return "STAGR ";
          when BIFOP_STAGW  => return "STAGW ";
          when BIFOP_LOCK   => return "LOCK  ";
          when BIFOP_FLUSH  => return "FLUSH ";
          when BIFOP_DPASS  => return "DPASS ";
          when BIFOP_STAGRX => return "STAGRX";
          when BIFOP_STORE  => return "STORE ";
          when BIFOP_SMFET  => return "SMFET ";
          when BIFOP_DLFET  => return "DLFET ";
          when BIFOP_ILFET  => return "ILFET ";
          when BIFOP_RESV1  => return "RESV1 ";
          when BIFOP_FFLUSH => return "FFLUSH";
          when BIFOP_AREGW  => return "AREGW ";
          when BIFOP_AREGR  => return "AREGR ";
          when others       => return "XXXXXX";
        end case;
      end bifopname;
      function xinfo(i: busif_in_type5) return string is
      begin
        case i.bifop is
          when BIFOP_NOP    => return "";
          when BIFOP_DTAGW  => return "";
          when BIFOP_STAGR  => return "";
          when BIFOP_STAGW  => return "";
          when BIFOP_LOCK   => return "";
          when BIFOP_FLUSH | BIFOP_FFLUSH =>
            return (" set=" & tost(i.busaddr(DOFFSET_HIGH downto DOFFSET_LOW)) &
                    " ways=" & tost(i.stdata(3 downto 0)) &
                    " unmsb=" & tost(i.stdata(11 downto 4)) );
          when BIFOP_DPASS  => return "";
          when BIFOP_STAGRX => return "";
          when BIFOP_STORE  => return "";
          when BIFOP_SMFET  => return "";
          when BIFOP_DLFET  => return "";
          when BIFOP_ILFET  => return "";
          when BIFOP_RESV1  => return "";
          when BIFOP_AREGW  => return "";
          when BIFOP_AREGR  => return "";
          when others       => return "";
        end case;
      end xinfo;
      variable b: busif_in_type5;
    begin
      b.bifop := bifi_bifop;
      b.busaddr := bifi_busaddr;
      b.stdata := bifi_stdata;
      if rising_edge(clk) then
        if r.bifready='1' and (bifi_bifop /= BIFOP_NOP and bifi_bifop /= BIFOP_LOCK) then
          grlib.testlib.print("bif " & busid & ": " & bifopname(bifi_bifop) & " " & tost(bifi_busaddr) & xinfo(b));
        end if;
      end if;
    end process;
  end generate;
--pragma translate_on

end;
