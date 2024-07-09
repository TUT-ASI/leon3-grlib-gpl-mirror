------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
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
-- Entity:      dmnvx
-- File:        dmnvx.vhd
-- Author:      Nils Wessman
-- Description: NOEL-V debug module
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.log2x;
use grlib.stdlib.orv;
use grlib.stdlib.notx;
use grlib.stdlib.zero32;
use grlib.stdlib.conv_std_logic;
use grlib.stdlib.conv_integer;
use grlib.stdlib."+";
use grlib.devices.all;
use grlib.stdlib.tost;
library gaisler;
use gaisler.noelv.XLEN;
use gaisler.noelv.nv_dm_in_type;
use gaisler.noelv.nv_dm_out_type;
use gaisler.noelv.nv_debug_in_vector;
use gaisler.noelv.nv_debug_out_vector;
use gaisler.dmnvint.all;
library techmap;
use techmap.gencomp.all;

entity dmnvx is
  generic (
    -- Debug Module
    nharts      : integer                       := 1;   -- number of harts
    nhgroups    : integer                       := 4;   -- Number of halt groups
    nrgroups    : integer                       := 4;   -- Number of resume groups
    datacount   : integer range 0  to 12        := 4;   -- Number of data registers
    nscratch    : integer range 0  to 2         := 2;   -- Number of scratch registers
    unavailtimeout:integer range 0  to 1024     := 64;  -- Clock cycles timeout
    progbufsize : integer range 0  to 16        := 8;   -- Program Buffer Size
    scantest    : integer                       := 0
    );
  port (
    clk    : in  std_ulogic;
    rstn   : in  std_ulogic;
    dmi    : in  dev_reg_in_type;
    dmo    : out dev_reg_out_type;
    dbgi   : in  nv_debug_out_vector(0 to NHARTS-1);
    dbgo   : out nv_debug_in_vector(0 to NHARTS-1);
    dsui   : in  nv_dm_in_type;
    dsuo   : out nv_dm_out_type
    );

end;

architecture rtl of dmnvx is

  -- Constants --------------------------------------------------------------

  --constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant RESET_ALL    : boolean := true;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  constant MAXHART      : integer := 2**20;
  constant UNAVAIL_H    : integer := log2x(unavailtimeout)-1;
  constant ADDR_H       : integer := 9;
  constant ALLHARTS     : std_logic_vector(NHARTS-1 downto 0) := (others => '1');

  -- Debug Module
  constant HARTSELLEN   : integer               := log2x(nharts);
  constant IMPEBREAK    : std_ulogic            := '0';
  constant DMVERSION    : std_logic_vector(3 downto 0) := "0010"; -- Version 0.14

  constant CMDERR_NONE          : std_logic_vector(2 downto 0) := "000";
  constant CMDERR_BUSY          : std_logic_vector(2 downto 0) := "001";
  constant CMDERR_NOTSUPPORTED  : std_logic_vector(2 downto 0) := "010";
  constant CMDERR_EXCEPTION     : std_logic_vector(2 downto 0) := "011";
  constant CMDERR_HALTRESUME    : std_logic_vector(2 downto 0) := "100";
  constant CMDERR_BUS           : std_logic_vector(2 downto 0) := "101";
  constant CMDERR_OTHER         : std_logic_vector(2 downto 0) := "111";

  constant CMDTYPE_REG          : std_logic_vector(7 downto 0) := "00000000";
  constant CMDTYPE_QUICK        : std_logic_vector(7 downto 0) := "00000001";
  constant CMDTYPE_MEM          : std_logic_vector(7 downto 0) := "00000010";

  -- Types ------------------------------------------------------------------

  type data_type    is array (0 to DATACOUNT-1) of std_logic_vector(31 downto 0);
--  type databuf_type is array (0 to XLEN/32-1) of word;

  type dmcontrol_type is record
    haltreq         : std_ulogic;
    resumereq       : std_ulogic;
    hartreset       : std_ulogic;
    ackhavereset    : std_ulogic;
    hasel           : std_ulogic;
    hartsel         : std_logic_vector(HARTSELLEN-1 downto 0);
    ndmreset        : std_ulogic;
    dmactive        : std_ulogic;
    setresethaltreq : std_ulogic;
    clrresethaltreq : std_ulogic;
  end record;

  constant dmcontrol_reset : dmcontrol_type := (
    haltreq         => '0',
    resumereq       => '0',
    hartreset       => '0',
    ackhavereset    => '0',
    hasel           => '0',
    hartsel         => (others => '0'),
    ndmreset        => '0',
    dmactive        => '0',
    setresethaltreq => '0',
    clrresethaltreq => '0'
    );

  type abscommand_type is record
    valid       : std_logic;
    cmdtype     : std_logic_vector(7 downto 0);
    aarsize     : std_logic_vector(2 downto 0);
    aarpostinc  : std_logic;
    postexec    : std_logic;
    transfer    : std_logic;
    write       : std_logic;
    regno       : std_logic_vector(15 downto 0);
  end record;
  constant abscommand_reset : abscommand_type := (
    valid       => '0',
    cmdtype     => (others => '0'),
    aarsize     => (others => '0'),
    aarpostinc  => '0',
    postexec    => '0',
    transfer    => '0',
    write       => '0',
    regno       => (others => '0')
  );

  type sbcontrol_type is record
    sbbusyerror     : std_logic;
    sbbusy          : std_logic;
    sbreadonaddr    : std_logic;
    sbaccess        : std_logic_vector(2 downto 0);
    sbautoincrement : std_logic;
    sbreadondata    : std_logic;
    sberror         : std_logic_vector(2 downto 0);
  end record;
  constant sbcontrol_reset : sbcontrol_type := (
    sbbusyerror     => '0',
    sbbusy          => '0',
    sbreadonaddr    => '0',
    sbaccess        => "010",
    sbautoincrement => '0',
    sbreadondata    => '0',
    sberror         => (others => '0')
  );

  type autoexec_type is record
    data    : std_logic_vector(DATACOUNT-1 downto 0);
    progbuf : std_logic_vector(PROGBUFSIZE-1 downto 0);
  end record;
  constant autoexec_reset : autoexec_type := (
    data    => (others => '0'),
    progbuf => (others => '0')
  );

  type group_type is array (natural range <>) of std_logic_vector(NHARTS-1 downto 0);

  type reg_type is record
    -- DSU Interface
    dsuen       : std_logic_vector(2 downto 0);
    dsubr       : std_logic_vector(2 downto 0);
    break       : std_ulogic;
    -- From Debug Module to Harts
    en          : std_logic_vector(NHARTS-1 downto 0);
    ghaltpend   : std_logic_vector(NHARTS-1 downto 0); -- Hart is pending to be halted due to halt group
    gresumepend : std_logic_vector(NHARTS-1 downto 0); -- Hart is pending to be resumed due to resume group
    hawindow    : std_logic_vector(NHARTS-1 downto 0);
    data        : data_type;
    control     : dmcontrol_type;
    hgroups     : group_type(0 to nhgroups-1);         -- Stores which hart belongs to each halt group
    rgroups     : group_type(0 to nrgroups-1);         -- Stores which hart belongs to each resume group
    grouptype   : std_ulogic;
    cmd         : abscommand_type;
    autoexec    : autoexec_type;
    busy        : std_ulogic;
    accerr      : std_ulogic;
    cmderr      : std_logic_vector(2 downto 0);
    unavailcnt  : std_logic_vector(UNAVAIL_H downto 0);
    haltonrst   : std_logic_vector(NHARTS-1 downto 0);
    -- System Bus Access
    sbcontrol   : sbcontrol_type;
    psberror    : std_logic_vector(2 downto 0);   -- Precalculated sberror
    sbaddress   : std_logic_vector(31 downto 0);
    sbdata      : std_logic_vector(31 downto 0);  -- Transfers wider than 32 bits are not allowed
    -- From Harts to Debug Module
    running     : std_logic_vector(NHARTS-1 downto 0);
    halted      : std_logic_vector(NHARTS-1 downto 0);
    resumeack   : std_logic_vector(NHARTS-1 downto 0);
    resumereq   : std_logic_vector(NHARTS-1 downto 0);
    havereset   : std_logic_vector(NHARTS-1 downto 0);
  end record;

  constant RES_T : reg_type := (
    -- DSU Interface
    dsuen       => (others => '0'),
    dsubr       => (others => '0'),
    break       => '0',
    -- From Debug Module to Harts
    en          => (others => '0'),
    --halt        => (others => '0'),
    --resume      => (others => '0'),
    --reset       => (others => '0'),
    ghaltpend   => (others => '0'),
    gresumepend => (others => '0'),
    hawindow    => (others => '0'),
    data        => (others => zero32),
    control     => dmcontrol_reset,
    hgroups     => (others => (others => '0')),
    rgroups     => (others => (others => '0')),
    grouptype   => '0',
    cmd         => abscommand_reset,
    autoexec    => autoexec_reset,
    busy        => '0',
    accerr      => '0',
    cmderr      => (others => '0'),
    unavailcnt  => (others => '0'),
    haltonrst   => (others => '0'),
    -- System Bus Access
    sbcontrol   => sbcontrol_reset,
    psberror    => (others => '0'),
    sbaddress   => (others => '0'),
    sbdata      => (others => '0'),
    -- From Harts to Debug Module
    running     => (others => '0'),
    halted      => (others => '0'),
    resumeack   => (others => '0'),
    resumereq   => (others => '0'),
    havereset   => (others => '0')
    );

  -- Signals ----------------------------------------------------------------

  signal r, rin         : reg_type;
  signal arst           : std_ulogic;
  signal pbo            : nv_progbuf_out_vector(0 to NHARTS-1);
  signal pbi            : nv_progbuf_in_vector(0 to NHARTS-1);

  -- Functions and Procedures -----------------------------------------------

begin

  arst        <= dmi.testrst when (ASYNC_RESET and scantest/=0 and dmi.testen/='0') else
                 rstn when ASYNC_RESET else '1';

  comb : process (rstn, r, dmi, dbgi, dsui, pbo)
    variable v                  : reg_type;
    -- Debug Module Registers
    variable dmstatus           : std_logic_vector(31 downto 0);
    variable hartinfo           : std_logic_vector(31 downto 0);
    variable abstractcs         : std_logic_vector(31 downto 0);
    variable command            : std_logic_vector(31 downto 0);
    variable sbcs               : std_logic_vector(31 downto 0);
    variable cap                : std_logic_vector(31 downto 0);
    variable ihartselraw        : integer range 0 to (2**HARTSELLEN)-1;
    variable hartselmaskraw     : std_logic_vector((2**HARTSELLEN)-1 downto 0);
    variable hartselmask        : std_logic_vector(NHARTS-1 downto 0);
    variable hartselvalid       : std_ulogic;
    variable hartsel_hi_lo      : std_logic_vector(19 downto 0);
    variable ihartsel           : integer range 0 to NHARTS-1;
    variable iregindex          : integer range 0 to 15;
    variable allhavereset       : std_ulogic;
    variable anyhavereset       : std_ulogic;
    variable allresumeack       : std_ulogic;
    variable anyresumeack       : std_ulogic;
    variable allnonexistent     : std_ulogic;
    variable anynonexistent     : std_ulogic;
    variable allunavail         : std_ulogic;
    variable anyunavail         : std_ulogic;
    variable allrunning         : std_ulogic;
    variable anyrunning         : std_ulogic;
    variable allhalted          : std_ulogic;
    variable anyhalted          : std_ulogic;
    variable dmactive           : std_ulogic;
    variable haltreq            : std_logic_vector(NHARTS-1 downto 0);
    variable resumereq          : std_logic_vector(NHARTS-1 downto 0);
    variable hartreset          : std_logic_vector(NHARTS-1 downto 0);
    -- REG Interface
    variable rdata              : std_logic_vector(regw-1 downto 0);
    -- Command Interface
    variable cmdenable          : std_ulogic;
    variable denable            : std_logic_vector(NHARTS-1 downto 0);
    variable dcmd               : std_logic_vector(1 downto 0);
    variable dwrite             : std_ulogic;
    variable dsize              : std_logic_vector(2 downto 0);
    variable daddr              : std_logic_vector(dbgo(0).daddr'range);
    variable ddata              : std_logic_vector(63 downto 0);
    variable dvalid             : std_ulogic;
    variable drdata             : std_logic_vector(63 downto 0);
    variable derr               : std_ulogic;
    variable dexec_done         : std_ulogic;
    variable pbwrite            : std_logic_vector(NHARTS-1 downto 0);
    -- Hatl groups
    variable clrghaltpend        : std_logic_vector(NHARTS-1 downto 0);
    variable clrgresumepend      : std_logic_vector(NHARTS-1 downto 0);



    procedure dm_reg_access(
      addr    : in  std_logic_vector(31 downto 0);
      wr      : in  std_ulogic;
      wdata   : in  std_logic_vector;
      rdata   : out std_logic_vector) is
      variable vrd     : std_logic_vector(31 downto 0);
      variable vwd     : std_logic_vector(wdata'length - 1 downto 0);
      variable hasel2  : std_logic_vector(ADDR_H downto 6) := addr(ADDR_H downto 6);
      variable hasel3  : std_logic_vector(5 downto 2) := addr(5 downto 2);
    begin
      vwd := wdata;
      vrd := (others => '0');

      -- Read/Write access
      case hasel2 is
        when "0000" => -- Abstract Data 0 - Abstract Data 12
          case hasel3 is
            when "0000" | "0001" | "0010" | "0011" => null;
            when others =>
              if notx(hasel3) then
                iregindex := to_integer(unsigned(hasel3)) - 4;
              else
                iregindex := 0;
              end if;
              if iregindex < DATACOUNT then
                vrd           := r.data(iregindex);
                if wr = '1' then
                  v.data(iregindex)     := vwd;
                end if;
                -- Automatically rerun abstract command when data is accessed
                if r.busy = '0' and r.autoexec.data(iregindex) = '1' and r.cmderr = CMDERR_NONE then
                  v.cmd.valid := '1';
                end if;
              end if;
              -- Accessing these registers while an abstract command is executing causes cmderr
              -- to be set to 1 (busy) if it is 0.
              if r.busy = '1' and r.cmderr = CMDERR_NONE then
                v.cmderr        := CMDERR_BUSY;
                v.accerr        := '1';
              end if;
          end case; --hasel3;
        when "0001" =>
          case hasel3 is
            when "0000" => -- Debug Module Control
              vrd(29)                 := r.control.hartreset;
              vrd(26)                 := r.control.hasel;
              hartsel_hi_lo(HARTSELLEN-1 downto 0) := r.control.hartsel;
              vrd(25 downto 16)       := hartsel_hi_lo(9 downto 0);
              vrd(15 downto 6)        := hartsel_hi_lo(19 downto 10);
              vrd(1)                  := r.control.ndmreset;
              vrd(0)                  := r.control.dmactive;
              if wr = '1' then
                v.control.haltreq         := vwd(31);
                v.control.resumereq       := vwd(30);
                v.control.hartreset       := vwd(29);
                v.control.ackhavereset    := vwd(28);
                v.control.hasel           := vwd(26);
                hartsel_hi_lo             := vwd(15 downto 6) & vwd(25 downto 16);
                v.control.hartsel         := hartsel_hi_lo(HARTSELLEN-1 downto 0);
                v.control.setresethaltreq := vwd(3);
                v.control.clrresethaltreq := vwd(2);
                v.control.ndmreset        := vwd(1);
                v.control.dmactive        := vwd(0);
              end if;
            when "0001" => -- Debug Module Status
              -- These entire registers are read-only
              vrd                     := dmstatus;
            when "0010" => -- Hart Info
              -- These entire registers are read-only
              vrd                     := hartinfo;
            when "0011" => -- Halt Summary 1
              -- This register is not implemented
              null;
            when "0100" => -- Hart Array Window Select
              -- This register is tied to 0
              null;
            when "0101" => -- Hart Array Window
              vrd(NHARTS-1 downto 0)  := r.hawindow;
              if wr = '1' then
                v.hawindow  := vwd(NHARTS-1 downto 0);
              end if;
            when "0110" => -- Abstract Control and Status
              vrd             := abstractcs;
              if wr = '1' then
                -- Writing this register while an abstract command is executing causes cmderr
                -- to be set to 1 (busy) if it is 0.
                if r.busy = '1' then
                  v.cmderr    := CMDERR_BUSY;
                  v.accerr    := '1';
                elsif vwd(10 downto 8) = "111" then
                  v.cmderr      := CMDERR_NONE;
                end if;
              end if;
            when "0111" => -- Abstract Command
              vrd             := command;
              if wr = '1' then
                -- Writing this register while an abstract command is executing causes cmderr
                -- to be set to 1 (busy) if it is 0.
                -- If cmderr is non-zero, writes to this register are ignored.
                if r.cmderr = CMDERR_NONE then
                  if r.busy = '1' then
                    v.cmderr      := CMDERR_BUSY;
                    v.accerr      := '1';
                  else
                    v.cmd.cmdtype   := vwd(31 downto 24);
                    v.cmd.aarsize   := vwd(22 downto 20);
                    v.cmd.aarpostinc:= vwd(          19);
                    v.cmd.postexec  := vwd(          18);
                    v.cmd.transfer  := vwd(          17);
                    v.cmd.write     := vwd(          16);
                    v.cmd.regno     := vwd(15 downto  0);
                    v.cmd.valid     := '1';
                  end if;
                end if;
              end if;
            when "1000" => -- Abstract Command Autoexec
              vrd(16+PROGBUFSIZE-1 downto  16)  := r.autoexec.progbuf;
              vrd(DATACOUNT-1 downto 0)         := r.autoexec.data;
              if wr = '1' then
                -- Writing this register while an abstract command is executing causes cmderr
                -- to be set to 1 (busy) if it is 0.
                if r.busy = '1' then
                  v.cmderr      := CMDERR_BUSY;
                  v.accerr      := '1';
                end if;
                v.autoexec.progbuf := vwd(16+PROGBUFSIZE-1 downto  16);
                v.autoexec.data    := vwd(DATACOUNT-1 downto 0);
              end if;
            when "1001" | "1010" | "1011" | "1100" => -- Device Tree Addr 0 - 3
              -- This registers are not implemented
              null;
            when "1101" => -- Next Debug Module
              -- This entire register is read-only
              null;
            when "1111" => -- Custom Feature
              vrd             := cap;
            when others => null;
          end case; -- hasel3
        when "0010" => -- Program Buffer 0 - Program Buffer 15
          if notx(hasel3) then
            iregindex     := to_integer(unsigned(hasel3));
          else
            iregindex     := 0;
          end if;
          if iregindex < PROGBUFSIZE then
            vrd       := pbo(ihartsel).data;
            if r.busy = '0' then
              if wr = '1' then
                pbwrite(ihartsel) := '1';
              end if;
              -- Automatically rerun abstract command when program buffer is accessed
              if r.autoexec.progbuf(iregindex) = '1' and r.cmderr = CMDERR_NONE then
                v.cmd.valid := '1';
              end if;
            end if;
          end if;
          -- Accessing these registers while an abstract command is executing causes cmderr
          -- to be set to 1 (busy) if it is 0.
          if r.busy = '1' and r.cmderr = CMDERR_NONE then
            v.cmderr    := CMDERR_BUSY;
            v.accerr    := '1';
          end if;
        when "0011" =>
          case hasel3 is
            when "0010" => -- Debug Module Control and Status 2 
              -- Read
              if nrgroups > 0 then
                vrd(11)           := r.grouptype;
              end if;
              if r.grouptype = '0' then    -- halt groups
                if nhgroups > 0 then
                  for i in 0 to nhgroups-1 loop
                    if r.hgroups(i)(to_integer(unsigned(r.control.hartsel))) = '1' then
                      vrd(6 downto 2)   := std_logic_vector(to_unsigned(i, 5));
                    end if;
                  end loop;
                end if;
              else                       -- resume groups
                if nrgroups > 0 then
                  for i in 0 to nrgroups-1 loop
                    if r.rgroups(i)(to_integer(unsigned(r.control.hartsel))) = '1' then
                      vrd(6 downto 2)   := std_logic_vector(to_unsigned(i, 5));
                    end if;
                  end loop;
                end if;
              end if;
              -- Write
              if wr = '1' then
                if nrgroups > 0 then
                  v.grouptype   :=  vwd(11); 
                end if;
                if vwd(1) = '1' then   -- hgwrite = 1
                  if vwd(11) = '0' then      -- group type = 0
                    if nhgroups > 0 and unsigned(vwd(6 downto 2)) < nhgroups then
                      for i in 0 to nhgroups-1 loop
                        v.hgroups(i)(to_integer(unsigned(r.control.hartsel))) := '0';
                      end loop;
                      v.hgroups(to_integer(unsigned(vwd(6 downto 2))))(to_integer(unsigned(r.control.hartsel))) := '1';
                    end if;
                  else                       -- group type = 1
                    if nrgroups > 0 and unsigned(vwd(6 downto 2)) < nrgroups then
                      for i in 0 to nrgroups-1 loop
                        v.rgroups(i)(to_integer(unsigned(r.control.hartsel))) := '0';
                      end loop;
                      v.rgroups(to_integer(unsigned(vwd(6 downto 2))))(to_integer(unsigned(r.control.hartsel))) := '1';
                    end if;
                  end if;
                end if;
              end if;
            when "1000" => -- System Bus Access Control (0x38)
              -- Read
              vrd(31 downto 29) := "001";                       -- sbversion
              vrd(22)           := r.sbcontrol.sbbusyerror;     
              vrd(21)           := v.sbcontrol.sbbusy;                  
              vrd(20)           := r.sbcontrol.sbreadonaddr;    
              vrd(19 downto 17) := r.sbcontrol.sbaccess;        
              vrd(16)           := r.sbcontrol.sbautoincrement; 
              vrd(15)           := r.sbcontrol.sbreadondata; 
              vrd(14 downto 12) := r.sbcontrol.sberror;       
              vrd(11 downto  5) := "0100000";                   -- sbasize (32)
              vrd( 2 downto  0) := "111";                       -- sbaccess32, sbaccess16, sbaccess8
              -- Write
              if wr = '1' then
                if vwd(22) = '1' then
                  v.sbcontrol.sbbusyerror := '0';
                end if;
                v.sbcontrol.sbreadonaddr     := vwd(20);
                v.sbcontrol.sbaccess         := vwd(19 downto 17);
                v.sbcontrol.sbautoincrement  := vwd(16);
                v.sbcontrol.sbreadondata     := vwd(15);
                if vwd(14 downto 12) = "111" then
                  v.sbcontrol.sberror := "000";
                end if;
              end if;

            when "1001" => -- System Bus Address (31 downto 0)  (0x39)
              -- Read
              vrd := r.sbaddress;     
              -- Write
              if wr = '1' then
                if r.sbcontrol.sbbusy = '1' then
                  v.sbcontrol.sbbusyerror := '1';
                else
                  v.sbaddress := vwd;
                  if r.sbcontrol.sbbusyerror = '0' and r.sbcontrol.sbreadonaddr = '1' and r.sbcontrol.sberror = "000" then
                    -- We need to check also here for the alignment and access errors
                    -- precalculation is not ready until next cycle
                    if unsigned(r.sbcontrol.sbaccess) > 2 then
                      -- Set size error
                      v.sbcontrol.sberror := r.psberror;
                    elsif (r.sbcontrol.sbaccess = "001" and vwd(0) /= '0') or 
                          (r.sbcontrol.sbaccess = "010" and vwd(1 downto 0) /= "00") then 
                      -- Set alignement error
                      v.sbcontrol.sberror := "011";
                    else 
                      -- Perform a read transfer
                      v.sbcontrol.sbbusy := '1';
                      dmo.sbstart        <= '1';
                      dmo.sbwr           <= '0';
                    end if;
                  end if;
                end if;
              end if;

            when "1100" => -- System Bus Data (31 downto 0)  (0x3c)
              -- Read
              vrd := r.sbdata(31 downto 0);
              if r.sbcontrol.sbbusy = '1' then
                v.sbcontrol.sbbusyerror := '1';
              elsif r.sbcontrol.sbbusyerror = '0' and r.sbcontrol.sberror = "000" then
                if r.psberror = "000" then
                  if wr = '0' then
                    if r.sbcontrol.sbreadondata = '1' then
                      -- Perform a read transfer
                      v.sbcontrol.sbbusy := '1';
                      dmo.sbstart        <= '1';
                      dmo.sbwr           <= '0';
                    end if;
                  else
                    -- Perform a write transfer
                    v.sbdata(31 downto 0) := vwd;
                    v.sbcontrol.sbbusy    := '1';
                    dmo.sbstart           <= '1';
                    dmo.sbwr              <= '1';
                  end if;
                else
                  -- Set error
                  v.sbcontrol.sberror := r.psberror;
                end if;
              end if;
              

            when "0000" | "0100" | "0101" =>
              -- Authentication Data
              -- Halt Summary 2
              -- Halt Summary 3
              -- These registers are not implemented
              null;
            when others =>
              -- All the other registers are not implemented
              null;
          end case; -- hasel3
        when "0100" => -- Halt Summary 0
          -- This entire register is read-only
          vrd(NHARTS-1 downto 0)      := r.halted;
        when others => null;
      end case; -- hasel2
      rdata := vrd;
    end dm_reg_access;

  begin

    ---------------------------------------------------------------------------------
    -- Defaults
    ---------------------------------------------------------------------------------
    v := r;

    -- Run Control
    v.control.resumereq       := '0';
    v.control.ackhavereset    := '0';
    v.control.setresethaltreq := '0';
    v.control.clrresethaltreq := '0';

    -- Program buffer
    pbwrite := (others => '0');

    -- System Bus Access
    dmo.sbstart <= '0';
    dmo.sbwr    <= '0';

    ---------------------------------------------------------------------------------
    -- Generate Hart Sel Signal
    ---------------------------------------------------------------------------------

    -- hasel is hard-wired to 0
    hartsel_hi_lo               := (others => '0');
    hartselmaskraw              := (others => '0');
    if notx(r.control.hartsel) then
      ihartselraw               := to_integer(unsigned(r.control.hartsel));
    else
      ihartselraw               := 0;
    end if;
    hartselmaskraw(ihartselraw) := '1';
    hartselmask                 := hartselmaskraw(NHARTS-1 downto 0);
    if r.control.hasel = '1' then
      hartselmask := hartselmask or r.hawindow;
    end if;
    hartselvalid                := orv(hartselmask);

    ihartsel                    := 0;
    if ihartselraw < NHARTS then
      ihartsel                  := ihartselraw;
    end if;

    -- When hasel is 1

    ---------------------------------------------------------------------------------
    -- Debug Module Registers
    ---------------------------------------------------------------------------------

    -- Debug Module Status (dmstatus, at 0x11)

    -- This field is 1 when all currently selected harts have been reset but the reset has
    -- not been acknowledged.
    allhavereset        := '0';
    if (r.havereset and hartselmask) = hartselmask and hartselvalid = '1' then
      allhavereset      := '1';
    end if;

    -- This field is 1 when any currently selected harts have been reset but the reset has
    -- not been acknowledged.
    anyhavereset        := hartselvalid;
    if not(r.havereset and hartselmask) = ALLHARTS then
      anyhavereset      := '0';
    end if;

    -- This field is 1 when all currently selected harts have acknowledged the previous
    -- resume request.
    allresumeack        := '0';
    if (r.resumeack and hartselmask) = hartselmask and hartselvalid = '1' then
      allresumeack      := '1';
    end if;

    -- This field is 1 when any currently selected harts have acknowledged the previous
    -- resume request.
    anyresumeack        := hartselvalid;
    if not(r.resumeack and hartselmask) = ALLHARTS then
      anyresumeack      := '0';
    end if;

    -- This field is 1 when all currently selected harts do not exist in this system.
    allnonexistent      := '0';
    if hartselvalid = '0' then
      allnonexistent    := '1';
    end if;

    -- This field is 1 when any currently selected harts do not exist in this system.
    anynonexistent      := allnonexistent;

    -- This field is 1 when all currently selected harts are unavailable.
    allunavail          := '0';
    --if r.unavailcnt(UNAVAIL_H) = '1' then
    --  allunavail        := '1';
    --end if;

    -- This field is 1 when any currently selected harts are unavailable.
    anyunavail          := allunavail;

    -- This field is 1 when all currently selected harts are running.
    allrunning          := '0';
    if (r.running and hartselmask) = hartselmask and hartselvalid = '1' then
      allrunning        := '1';
    end if;

    -- This field is 1 when any currently selected harts are running.
    anyrunning          := hartselvalid;
    if not (r.running and hartselmask) = ALLHARTS then
      anyrunning        := '0';
    end if;

    -- This field is 1 when all currently selected harts are halted.
    allhalted           := '0';
    if (r.halted and hartselmask) = hartselmask and hartselvalid = '1' then
      allhalted         := '1';
    end if;

    -- This field is 1 when any currently selected harts are halted.
    anyhalted           := hartselvalid;
    if not (r.halted and hartselmask) = ALLHARTS then
      anyhalted         := '0';
    end if;

    dmstatus            := zero32;
    dmstatus(22)        := IMPEBREAK;
    dmstatus(19)        := allhavereset;
    dmstatus(18)        := anyhavereset;
    dmstatus(17)        := allresumeack;
    dmstatus(16)        := anyresumeack;
    dmstatus(15)        := allnonexistent;
    dmstatus(14)        := anynonexistent;
    dmstatus(13)        := allunavail;
    dmstatus(12)        := anyunavail;
    dmstatus(11)        := allrunning;
    dmstatus(10)        := anyrunning;
    dmstatus(9)         := allhalted;
    dmstatus(8)         := anyhalted;
    dmstatus(7)         := '1'; -- authenticated
    dmstatus(6)         := '0'; -- authbusy
    dmstatus(5)         := '1'; -- hasresethaltreq
    dmstatus(4)         := '0'; -- devtreevalid
    dmstatus(3 downto 0):= DMVERSION;

    -- Debug Module Control (dmcontrol, at 0x10)

    -- Hart Info (hartinfo, at 0x12)

    hartinfo                    := zero32;
    hartinfo(23 downto 20)      := std_logic_vector(to_unsigned(NSCRATCH, 4));

    -- Abstract Control and Status (abstractcs, at 0x16)

    abstractcs                  := zero32;
    abstractcs(28 downto 24)    := std_logic_vector(to_unsigned(PROGBUFSIZE, 5));
    abstractcs(12)              := r.busy;
    abstractcs(10 downto 8)     := r.cmderr;
    abstractcs(3 downto 0)      := std_logic_vector(to_unsigned(DATACOUNT, 4)); -- datacount

    -- Abstract Command (command, at 0x17)

    command                     := zero32;
    command(31 downto 24)       := r.cmd.cmdtype;
    command(22 downto 20)       := r.cmd.aarsize;
    command(          19)       := r.cmd.aarpostinc;
    command(          18)       := r.cmd.postexec;
    command(          17)       := r.cmd.transfer;
    command(          16)       := r.cmd.write;
    command(15 downto  0)       := r.cmd.regno;

    -- Abstract Command Autoexec (abstractauto, at 0x18)

    -- Device Tree Addr 0 (devtreeaddr0, at 0x19)

    -- Next Debug Module (nextdm, at 0x1d)

    -- Custom Feature (custom, at 0x1f)

    cap                         := zero32;
    cap(31 downto 24)           := std_logic_vector(to_unsigned(nharts - 1, 8));
    cap(23          )           := conv_std_logic(nharts <= 256);
    cap(21 downto 19)           := dbgi(0).cap(2 downto 0);
    --cap(           7)           := RESERVED
    cap( 6 downto  0)           := dbgi(0).cap(9 downto 3);

    -- Abstract Data 0 (data0, at 0x04)

    -- Program Buffer 0 (progbuf0, at 0x20)

    -- Authentication Data (authdata, at 0x30)

    -- Halt Summary 0 (haltsum0, at 0x40)

    -- System Bus Access Control and Status (sbcs, at 0x38)

    sbcs                := zero32;
    sbcs(31 downto 29)  := "001";
    sbcs(19 downto 17)  := "010";

    ---------------------------------------------------------------------------------
    -- REG Interface
    ---------------------------------------------------------------------------------
    rdata   := (others => '0');

    if dmi.sel(0) = '1' then
      dm_reg_access(dmi.addr, dmi.wr, dmi.data, rdata);
    end if;

    dmo.rdy   <= '1';
    dmo.data  <= rdata;

    ---------------------------------------------------------------------------------
    -- Run Control
    ---------------------------------------------------------------------------------

    -- For every hart, the Debug Module contains 4 conceptual bits of state: halt request,
    -- resume request, halt-on-reset request, and hart reset. (The hart reset and halt-on-reset
    -- request bits are optional.)

    -- These bits all reset to 0. A debugger can write them for the currently selected harts
    -- through haltreq, resumereq, setresethaltreq/clrresethaltreq and hartreset in dmcontrol.
    -- In addition the DM receives halted, running, and resume ack signals from each hart.
    -- When a running hart receives a halt request, it responds by halting, deasserting its
    -- running signal, and asserting its halted signal. The halted signals of all selected harts
    -- are reflected in the allhalted and anyhalted bits. haltreq is ignored by halted harts.

    -- When a halted hart receives a resume request, it responds by resuming, clearing its
    -- halted signal, and asserting its running signal and resume ack signals. The resume ack
    -- signal is lowered when the resume request is deasserted. These status signals of all
    -- selected harts are reflected in allresumeack, anyresumeack, allrunning, and anyrunning.
    -- resumereq is ignored by running harts.

    -- When halt or resume is requested, a hart must respond in less than one second, unless it
    -- is unavailable.

    -- Register Hart Signals
    for i in 0 to NHARTS-1 loop
      v.running(i)      := dbgi(i).running;
      v.halted(i)       := dbgi(i).halted;
      v.havereset(i)    := dbgi(i).havereset or r.havereset(i); -- sticky bit
    end loop;

    -- Filter dsu external signals and propagate to each harts
    v.dsuen             := r.dsuen(1 downto 0) & dsui.enable;
    v.dsubr             := r.dsubr(1 downto 0) & dsui.break;

    for i in 0 to NHARTS-1 loop
      v.en(i)           := r.dsuen(2) and dbgi(i).dsu;
    end loop;
    v.break             := r.dsubr(2);

    -- Generate halt signal
    haltreq             := (others => '0');
    if r.control.haltreq = '1' then
      haltreq           := hartselmask;
    end if;
    
    -- Generate halt signal for group harts
    if nhgroups > 0 then
      clrghaltpend := (others => '1');
      for i in 0 to NHARTS-1 loop
        if r.halted(i) = '0' and dbgi(i).halted = '1' then
          if r.ghaltpend(i) = '0' then
            -- if the hart was halted setting haltreq bit to 1 
            for j in 1 to nhgroups-1 loop
              if r.hgroups(j)(i) = '1' then
                v.ghaltpend     := v.ghaltpend or r.hgroups(j);
                -- The bit of the hart that was halted setting haltreq
                -- bit to 1 should not be set to 1
                clrghaltpend(i) := '0';
              end if;
            end loop;
            -- If hart inside of a group is already halted do nothing
            -- If hart is resuming, halt it when it finishes resuming
            v.ghaltpend := v.ghaltpend and not(r.halted and r.resumeack);
          else 
            -- if the hart was halted because another hart in the same 
            -- halt group has halted we clear the group halt request bit
            v.ghaltpend(i)  := '0';
          end if; 
        end if;
      end loop;
      v.ghaltpend  := v.ghaltpend and clrghaltpend;
    end if;



    -- Generate resume signal
    resumereq           := (others => '0');
    if r.control.resumereq = '1' and r.control.haltreq = '0' then
      v.resumereq       := hartselmask;
      v.resumeack       := r.resumeack and (not hartselmask);
    else
      for i in 0 to NHARTS-1 loop
        if r.resumereq(i) = '1' and r.running(i) = '1' then
          v.resumereq(i) := '0';
          v.resumeack(i) := '1';
        end if;
      end loop;
    end if;
    resumereq := r.resumereq;


    if nrgroups > 0 then
      -- Generate resume signal for group harts
      clrgresumepend := (others => '1');
      for i in 0 to NHARTS-1 loop
        if r.running(i) = '0' and dbgi(i).running = '1' then
          if r.gresumepend(i) = '0' then
            -- if the hart was resumed setting resumereq bit to 1 
            for j in 1 to nrgroups-1 loop
              if r.rgroups(j)(i) = '1' then
                v.gresumepend := v.gresumepend or r.rgroups(j);
                v.resumeack   := v.resumeack and (not r.rgroups(j));
                -- The bit of the hart that was resumed setting resumreq
                -- bit to 1 should not be set to 1
                clrgresumepend(i) := '0'; 
              end if;
            end loop;
            -- Do not resume if hart is in the halting process (running=1 and (haltreq or ghaltpen) = 1)
            -- If hart inside of a group is already running do nothing
            -- both conditions can be merged into the following one
            v.gresumepend := v.gresumepend and not(r.running);
            v.resumeack   := v.resumeack or r.running;
          else 
            -- if the hart was resumed because another hart in the same 
            -- resume group has resumed we clear the group resume request bit
            v.gresumepend(i) := '0';
            v.resumeack(i)   := '1';
          end if; 
        end if;
      end loop;
      v.gresumepend := v.gresumepend and clrgresumepend;
      v.resumeack   := v.resumeack and clrgresumepend;
    end if;

    -- Generate reset signal
    hartreset           := (others => '0');
    if r.control.hartreset = '1' then
      hartreset         := hartselmask;
    end if;

    -- Clear havereset signal
    if r.control.ackhavereset = '1' then
      v.havereset       := r.havereset and not(hartselmask);
    end if;

    -- Halt-on-reset
    if r.control.setresethaltreq = '1' then
      v.haltonrst := r.haltonrst or hartselmask;
    end if;
    if r.control.clrresethaltreq = '1' then
      v.haltonrst := r.haltonrst and (not hartselmask);
    end if;

    -- IDLE

    -- Send an halt requesto to the selected hart in the following cases:
    -- * halt request from write to the DM register
    -- * halt request from asserting the dsu.break pin (check if it is compliants)
    if r.break = '1' then
      haltreq           := hartselmask and r.en;
    end if;

    -- HALTING

    -- Check the running and halted signals from the selected hart
    -- If it does not replay within the timout, set the unavailable hart bit
    if hartselvalid = '1' and (haltreq(ihartsel) and r.en(ihartsel)) = '1' then
      if r.halted(ihartsel) = '1' and r.running(ihartsel) = '0' then
        v.unavailcnt    := (others => '0');
      else
        v.unavailcnt    := std_logic_vector(unsigned(r.unavailcnt) + 1);
      end if;
    end if;

    ---------------------------------------------------------------------------------
    -- Abstract command
    ---------------------------------------------------------------------------------

    -- Input Hart Signals
    dvalid              := dbgi(ihartsel).dvalid;
    drdata              := dbgi(ihartsel).ddata;
    derr                := dbgi(ihartsel).derr;
    dexec_done          := dbgi(ihartsel).dexec_done;

    -- COMMAND START

    -- Check for cmderror
    if v.cmd.valid = '1' then
      v.busy          := '1';
      if r.cmd.valid = '0' then v.accerr := '0'; end if;
      -- Not supported
      -- Only "Access Register Command" is supported
      if v.cmd.cmdtype /= CMDTYPE_REG then
        v.cmderr        := CMDERR_NOTSUPPORTED;
      end if;
      -- Halt/Resume
      if r.halted(ihartsel) = '0' then
        v.cmderr        := CMDERR_HALTRESUME;
      end if;
      -- Other
      if v.cmd.cmdtype = CMDTYPE_REG then
        if v.cmd.aarsize = "100" then
          v.cmderr      := CMDERR_OTHER;
        end if;
        if (v.cmd.transfer = '0' and v.cmd.postexec = '0') then
          v.cmd.valid := '0';
          v.busy      := '0';
        end if;
      end if;
    end if;

    dwrite      := '0';
    cmdenable   := '0';
    ddata       := (others => '0');
    daddr       := (others => '0');
    dcmd        := (others => '0');
    dsize       := (others => '0');

    -- Mask denable with cmderr in case of errors detected
    if r.cmd.valid = '1' and r.halted(ihartsel) = '1' and r.cmderr = CMDERR_NONE then
      case r.cmd.cmdtype is
        when CMDTYPE_REG =>
          -- Access Register Command
          cmdenable     := r.cmd.postexec or r.cmd.transfer;
          dwrite        := r.cmd.write;
          ddata         := r.data(1) & r.data(0); -- 128 bit access are not supported
          dsize         := r.cmd.aarsize;
          dcmd(0)       := r.cmd.transfer;
          dcmd(1)       := r.cmd.postexec;
          daddr         := r.cmd.regno;
        -- Other unsupported CMDTYPE detection has already been detected
        -- We raised errors previously
        when others => null;
      end case; -- r.cmd.cmdtype
    end if;

    -- Set enable signal for selected harts
    denable             := (others => '0');
    if hartselvalid = '1' then
      denable(ihartsel) := cmdenable;
    end if;

    -- COMMAND EXECUTE

    if r.cmd.valid = '1' then
      -- Annul command if error arises
      if r.cmderr /= CMDERR_NONE and v.accerr = '0' then
        v.cmd.valid := '0';
        v.busy      := '0';
      else
        -- Wait for response from harts
        if dvalid = '1' then
          -- Deassert cmdvalid and busy
          v.cmd.valid    := '0';
          -- Do not clear busy until prog buffer done
          if r.cmd.postexec = '0' then
            v.busy        := '0';
          end if;
          -- Assert error in case
          if derr = '1' and v.accerr = '0' then
            v.cmderr      := CMDERR_EXCEPTION;
          else
            -- Write back read values
            case r.cmd.cmdtype is
              when CMDTYPE_REG =>
                -- Save values into data register
                if r.cmd.transfer = '1' and r.cmd.write = '0' then
                  v.data(0)     := drdata(31 downto 0);
                  if r.cmd.aarsize = "011" then -- 64 bit access
                    v.data(1)   := drdata(63 downto 32);
                  end if;
                end if;
              when others => null;
            end case; -- r.cmd.cmdtype
          end if;
        end if;
      end if;
    end if;

    -- Detect when prog buffer execution done
    if r.cmd.postexec = '1' and dexec_done = '1' then
      v.busy  := '0';
      if derr = '1' and v.accerr = '0' then
        v.cmderr  := CMDERR_EXCEPTION;
      end if;
    end if;


    ---------------------------------------------------------------------------------
    -- System Bus Access
    ---------------------------------------------------------------------------------
    -- When a transfer finishes:
    -- Clear busy bit, update the read data, update error values and 
    -- increment the address 
    if dmi.sbfinish = '1' then
        v.sbcontrol.sbbusy := '0';
        if dmi.sberror = '1' then
          v.sbcontrol.sberror := "111"; 
        else
          if dmi.sbdvalid = '1' then
            v.sbdata := std_logic_vector(shift_right(unsigned(dmi.sbrdata), conv_integer(r.sbaddress(1 downto 0))*8)) ;
          end if;
          if r.sbcontrol.sbautoincrement = '1' then
            case r.sbcontrol.sbaccess is
              when "000" => --   8 bit access
                v.sbaddress := r.sbaddress + 1;
              when "001" => --  16 bit access
                v.sbaddress := r.sbaddress + 2;
              when "010" => --  32 bit access
                v.sbaddress := r.sbaddress + 4;
              when others =>
                null;
            end case;
          end if;
        end if;
    end if;


    -- Check for size access and alignement errors
    if unsigned(r.sbcontrol.sbaccess) > 2 then
      v.psberror := "100";
    elsif (r.sbcontrol.sbaccess = "001" and r.sbaddress(0) /= '0') or 
          (r.sbcontrol.sbaccess = "010" and r.sbaddress(1 downto 0) /= "00") then 
      v.psberror := "011" ;
    else
      v.psberror := "000";
    end if;


    dmo.sbaddr   <= r.sbaddress;
    dmo.sbwdata  <= std_logic_vector(shift_left(unsigned(r.sbdata), conv_integer(r.sbaddress(1 downto 0))*8)) ;
    dmo.sbaccess <= r.sbcontrol.sbaccess;


    ---------------------------------------------------------------------------------
    -- Reset
    ---------------------------------------------------------------------------------

    -- This bit serves as a reset signal for the Debug Module itself.
    -- 0: The module’s state, including authentication mechanism, takes its reset values
    -- (the dmactive bit is the only bit which can be written to something other than
    -- its reset value).
    -- 1: The module functions normally.
    --
    -- No other mechanism should exist that may result in resetting the Debug Module after
    -- power up, including the platform’s system reset or Debug Transport reset signals.
    dmactive            := v.control.dmactive;
    if r.control.dmactive = '0' then
      --v.dsuen           := (others => '0');
      --v.dsubr           := (others => '0');
      v.break           := '0';
      v.en              := (others => '0');
      --v.halt            := (others => '0');
      --v.resume          := (others => '0');
      --v.reset           := (others => '0');
      v.ghaltpend       := (others => '0');
      v.gresumepend     := (others => '0');
      v.hgroups         := (others => (others => '0'));
      v.hgroups(0)      := (others => '1');
      v.rgroups         := (others => (others => '0'));
      v.rgroups(0)      := (others => '1');
      v.grouptype       := '0';
      v.sbcontrol       := sbcontrol_reset;
      v.psberror        := (others => '0');
      v.sbaddress       := (others => '0');
      v.sbdata          := (others => '0');
      v.hawindow        := (others => '0');
      v.data            := (others => zero32);
      v.control         := dmcontrol_reset;
      v.control.dmactive:= dmactive;
      v.cmd             := abscommand_reset;
      v.busy            := '0';
      v.cmderr          := (others => '0');
      v.unavailcnt      := (others => '0');
      v.running         := (others => '0');
      v.halted          := (others => '0');
      v.resumeack       := (others => '0');
      v.havereset       := (others => '0');
    end if;

    rin                 <= v;

    ---------------------------------------------------------------------------------
    -- Output Signals
    ---------------------------------------------------------------------------------

    dsuo.dmactive       <= r.control.dmactive;
    dsuo.ndmreset       <= not r.control.ndmreset;
    dsuo.pwd            <= (others => '0');

    for i in 0 to NHARTS-1 loop
      dbgo(i).dsuen     <= r.en(i);             -- DSU Enable
      dbgo(i).halt      <= haltreq(i) or r.ghaltpend(i);     -- Halt Request
      dbgo(i).haltgroup <= r.ghaltpend(i);                   -- Halt Group Request
      dbgo(i).resume    <= resumereq(i) or r.gresumepend(i); -- Resume Request
      dbgo(i).reset     <= hartreset(i);        -- Reset Request
      dbgo(i).haltonrst <= r.haltonrst(i);      -- Halt-on-reset
      dbgo(i).freeze    <= '0';                 -- Hold CPU
      dbgo(i).denable   <= denable(i);          -- Command Enable
      dbgo(i).dcmd      <= dcmd;                -- Command Type
      dbgo(i).dwrite    <= dwrite;              -- Write Enable
      dbgo(i).dsize     <= dsize;               -- Access Size
      dbgo(i).daddr     <= daddr;               -- Address
      dbgo(i).ddata     <= ddata;               -- Data

      -- Program execution
      pbi(i).eaddr      <= dbgi(i).pbaddr;
      dbgo(i).pbdata    <= pbo(i).edata;
      -- Program read/write
      pbi(i).addr       <= dmi.addr(6 downto 2);
      pbi(i).write      <= pbwrite(i);
      pbi(i).data       <= dmi.data;
    end loop;

  end process;

  regs : process(clk, rin, rstn)
  begin
    if rising_edge(clk) then
      r <= rin;
      if rstn = '0' then
        r <= RES_T;
        r.hgroups(0) <= (others => '1');
        r.rgroups(0) <= (others => '1');
        for i in 0 to NHARTS-1 loop
          r.haltonrst(i) <= r.dsubr(2);
        end loop;
        -- sync regs
        r.dsubr <= rin.dsubr;
        r.dsuen <= rin.dsuen;
      end if;
    end if;
  end process;

  -- Program buffer -------------------------------------------------------------
  pbgen : if progbufsize /= 0 generate
    x : for i in 0 to NHARTS-1 generate
      pb0 : progbuf
        generic map (
          size  => progbufsize)
        port map (
          clk   => clk,
          rstn  => rstn,
          pbi   => pbi(i),
          pbo   => pbo(i));
    end generate;
  end generate;

  nopbgen : if progbufsize = 0 generate
    x : for i in 0 to NHARTS-1 generate
      pbo(i) <= nv_progbuf_out_none;
    end generate;
  end generate;

end;

