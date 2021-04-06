------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
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
-- Entity:      spimctrl
-- File:        spimctrl.vhd
-- Author:      Jan Andersson - Cobham Gaisler AB
--              support@gaisler.com
--
-- Description: SPI flash memory controller. Supports a wide range of SPI
--              memory devices with the data read instruction configurable via
--              generics. Also has limited support for initializing and reading
--              SD Cards in SPI mode.
-- 
-- The controller has two memory areas. The flash area where the flash memory
-- is directly mapped and the I/O area where core registers are mapped.
--
-- Revision 1 added support for burst reads when sdcard = 0
--
-- Post revision 1: Remove support for SD card
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.spi.all;

entity spimctrl is
  generic (
    hindex      : integer := 0;            -- AHB slave index
    hirq        : integer := 0;            -- Interrupt line
    faddr       : integer := 16#000#;      -- Flash map base address
    fmask       : integer := 16#fff#;      -- Flash area mask
    ioaddr      : integer := 16#000#;      -- I/O base address
    iomask      : integer := 16#fff#;      -- I/O mask
    spliten     : integer := 0;            -- AMBA SPLIT support
    oepol       : integer := 0;            -- Output enable polarity
    sdcard      : integer range 0 to 0   := 0;  -- Unused
    readcmd     : integer range 0 to 255 := 16#0B#;  -- Mem. dev. READ command
    dummybyte   : integer range 0 to 1   := 1;  -- Dummy byte after cmd
    dualoutput  : integer range 0 to 1   := 0;  -- Enable dual output
    scaler      : integer range 1 to 512 := 1; -- SCK scaler
    altscaler   : integer range 1 to 512 := 1; -- Alternate SCK scaler 
    pwrupcnt    : integer  := 0;               -- Unused
    maxahbaccsz : integer range 0 to 256 := AHBDW; -- Max AHB access size
    offset      : integer := 0
    );
  port (
    rstn    : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
    spii    : in  spimctrl_in_type;
    spio    : out spimctrl_out_type
  );
end spimctrl;

architecture rtl of spimctrl is
  
  constant REVISION : amba_version_type := 1;

  constant HCONFIG : ahb_config_type := (
    0 => ahb_device_reg(VENDOR_GAISLER, GAISLER_SPIMCTRL, 0, REVISION, hirq),
    4 => ahb_iobar(ioaddr, iomask),
    5 => ahb_membar(faddr, '1', '1', fmask),
    others => zero32);

  -- BANKs
  constant CTRL_BANK  : integer := 0;
  constant FLASH_BANK : integer := 1;

  constant MAXDW : integer := maxahbaccsz;
    
  -----------------------------------------------------------------------------
  -- SPI device constants
  -----------------------------------------------------------------------------

  -- Length of read instruction argument-1 
  constant SPI_ARG_LEN : integer := 2 + dummybyte;
  
  -----------------------------------------------------------------------------
  -- Core constants
  -----------------------------------------------------------------------------
  
  -- OEN
  constant OUTPUT : std_ulogic := conv_std_logic(oepol = 1);  -- Enable outputs
  constant INPUT : std_ulogic := not OUTPUT;   -- Tri-state outputs
  
  -- Register offsets
  constant CONF_REG_OFF  : std_logic_vector(7 downto 2) := "000000";
  constant CTRL_REG_OFF  : std_logic_vector(7 downto 2) := "000001";
  constant STAT_REG_OFF  : std_logic_vector(7 downto 2) := "000010";
  constant RX_REG_OFF    : std_logic_vector(7 downto 2) := "000011";
  constant TX_REG_OFF    : std_logic_vector(7 downto 2) := "000100";
  
  -----------------------------------------------------------------------------
  -- Subprograms
  -----------------------------------------------------------------------------  
  -- Description: Determines required size of timer used for clock scaling
  function timer_size
    return integer is
  begin  -- timer_size
    if altscaler > scaler then
      return altscaler;
    end if;
    return scaler;
  end timer_size;

  -- Description: Returns the number of bits required for the haddr vector to
  -- be able to save the Flash area address.
  function req_addr_bits
    return integer is
  begin  -- req_addr_bits
    case fmask is
      when 16#fff# => return 20;
      when 16#ffe# => return 21;
      when 16#ffc# => return 22;
      when 16#ff8# => return 23;
      when 16#ff0# => return 24;
      when 16#fe0# => return 25;
      when 16#fc0# => return 26;
      when 16#f80# => return 27;
      when 16#f00# => return 28;
      when 16#e00# => return 29;
      when 16#c00# => return 30;
      when others  => return 31;
    end case;
  end req_addr_bits;
  
  -- Description: Returns true if SCK clock should transition
  function sck_toggle (
    curr         : std_logic_vector((timer_size-1) downto 0);
    last         : std_logic_vector((timer_size-1) downto 0);
    usealtscaler : boolean)
    return boolean is
  begin  -- sck_toggle
    if usealtscaler then
      return (curr(altscaler-1) xor last(altscaler-1)) = '1';
    end if;
    return (curr(scaler-1) xor last(scaler-1)) = '1';
  end sck_toggle;

  -- Description: Short for conv_std_logic_vector, avoiding an alias
  function cslv (
    i : integer;
    w : integer)
    return std_logic_vector is
  begin  -- cslv
    return conv_std_logic_vector(i,w);
  end cslv;

  -- Description: Calculates value for spi.cnt based on AMBA HSIZE
  function calc_spi_cnt (
    hsize : std_logic_vector(2 downto 0))
    return std_logic_vector is
    variable cnt : std_logic_vector(4 downto 0) := (others => '0');
  begin  -- calc_spi_cnt
    for i in 0 to 4 loop
      if i < conv_integer(hsize) then
        cnt(i) := '1';
      end if;
    end loop;  -- i
    return cnt;
  end calc_spi_cnt;
  
  -----------------------------------------------------------------------------
  -- States
  -----------------------------------------------------------------------------

  -- Main FSM states
  type spimstate_type is (IDLE, AHB_RESPOND, USER_SPI, BUSY);
  
  -- SPI device FSM states
 type spistate_type is (SPI_CSWAIT,  SPI_READY, SPI_READ, SPI_ADDR, SPI_DATA);
  
  -----------------------------------------------------------------------------
  -- Types
  -----------------------------------------------------------------------------  
  
  type spim_ctrl_reg_type is record     -- Control register
       eas  : std_ulogic;               -- Enable alternate scaler
       ien  : std_ulogic;               -- Interrupt enable
       usrc : std_ulogic;               -- User mode
  end record;

  type spim_stat_reg_type is record     -- Status register
      busy : std_ulogic;                -- Core busy
      done : std_ulogic;                -- User operation done
  end record;

  type spim_regif_type is record        -- Register bank
       ctrl : spim_ctrl_reg_type;       -- Control register
       stat : spim_stat_reg_type;       -- Status register
  end record;

  type spiflash_type is record
       state  : spistate_type;           -- Mem. device comm. state
       cnt    : std_logic_vector(4 downto 0);  -- Generic counter
       hsize  : std_logic_vector(2 downto 0);  -- Size of access
       hburst : std_logic_vector(0 downto 0);  -- Incremental burst
  end record;

  type spimctrl_in_array is array (1 downto 0) of spimctrl_in_type;
  
  type spim_reg_type is record
       -- Common
       spimstate      : spimstate_type;  -- Main FSM
       rst            : std_ulogic;      -- Reset
       reg            : spim_regif_type; -- Register bank
       timer          : std_logic_vector((timer_size-1) downto 0);
       sample         : std_logic_vector(1 downto 0);  -- Sample data line
       bd             : std_ulogic;
       sreg           : std_logic_vector(7 downto 0);  -- Shiftreg
       bcnt           : std_logic_vector(2 downto 0);  -- Bit counter
       go             : std_ulogic;     -- SPI comm. active
       stop           : std_ulogic;     -- Stop SPI comm.
       ar             : std_logic_vector(MAXDW-1 downto 0); -- argument/response
       hold           : std_ulogic;     -- Do not shift ar
       insplit        : std_ulogic;     -- SPLIT response issued
       unsplit        : std_ulogic;     -- SPLIT complete not issued
       -- SPI flash device
       spi            : spiflash_type;
       -- AHB
       irq            : std_ulogic;     -- Interrupt request
       hsize          : std_logic_vector(2 downto 0);
       hwrite         : std_ulogic;
       hsel           : std_ulogic;
       hmbsel         : std_logic_vector(0 to 1);
       haddr          : std_logic_vector((req_addr_bits-1) downto 0);
       hready         : std_ulogic;
       frdata         : std_logic_vector(MAXDW-1 downto 0);  -- Flash response data
       rrdata         : std_logic_vector(7 downto 0);  -- Register response data
       hresp          : std_logic_vector(1 downto 0);
       splmst         : std_logic_vector(log2(NAHBMST)-1 downto 0);  -- SPLIT:ed master
       hsplit         : std_logic_vector(NAHBMST-1 downto 0);  -- Other SPLIT:ed masters
       ahbcancel      : std_ulogic;     -- Locked access cancels ongoing SPLIT
                                        -- response
       hburst         : std_logic_vector(0 downto 0);
       seq            : std_ulogic;     -- Sequential burst
       -- Inputs and outputs
       spii           : spimctrl_in_array;
       spio           : spimctrl_out_type;
  end record;
  
  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  
  signal r, rin : spim_reg_type;
  
begin  -- rtl

  comb: process (r, rstn, ahbsi, spii)
    variable v                : spim_reg_type;
    variable change           : std_ulogic;
    variable regaddr          : std_logic_vector(7 downto 2);
    variable hsplit           : std_logic_vector(NAHBMST-1 downto 0);
    variable ahbirq           : std_logic_vector((NAHBIRQ-1) downto 0);
    variable lastbit          : std_ulogic;
    variable enable_altscaler : boolean;
    variable disable_flash    : boolean;
    variable read_flash       : boolean;
    variable hrdata           : std_logic_vector(MAXDW-1 downto 0);
    variable hwdatax          : std_logic_vector(31 downto 0);
    variable hwdata           : std_logic_vector(7 downto 0);
  begin  -- process comb
    v := r; v.spii := r.spii(0) & spii; v.sample := r.sample(0) & '0';
    change := '0'; v.irq := '0'; v.hresp := HRESP_OKAY; v.hready := '1';
    regaddr := r.haddr(7 downto 2); hsplit := (others => '0');
    hwdatax := ahbreadword(ahbsi.hwdata, r.haddr(4 downto 2));
    hwdata := hwdatax(7 downto 0);
    ahbirq := (others => '0'); ahbirq(hirq) := r.irq;
    read_flash := false;
    enable_altscaler := r.reg.ctrl.eas = '1';
    disable_flash := (r.reg.ctrl.usrc = '1' or r.spimstate = USER_SPI);
    if dualoutput = 1 then
      lastbit := andv(r.bcnt(1 downto 0)) and
                 ((r.spio.mosioen xnor INPUT) or r.bcnt(2)); 
    else
      lastbit := andv(r.bcnt);
    end if;
    v.bd := lastbit and r.sample(0); 
    
    ---------------------------------------------------------------------------
    -- AHB communication
    ---------------------------------------------------------------------------
    if ahbsi.hready = '1' then
      if (ahbsi.hsel(hindex) and ahbsi.htrans(1)) = '1' then
        v.hmbsel := ahbsi.hmbsel(r.hmbsel'range);
        if (spliten = 0 or r.spimstate /= AHB_RESPOND or
            ahbsi.hmbsel(CTRL_BANK) = '1' or ahbsi.hmastlock = '1') then
          -- Writes to register space have no wait state
          v.hready := ahbsi.hmbsel(CTRL_BANK) and ahbsi.hwrite;            
          v.hsize := ahbsi.hsize;
          v.hwrite := ahbsi.hwrite;
          v.haddr := ahbsi.haddr(r.haddr'range);
          v.hsel := '1';
          if ahbsi.hmbsel(FLASH_BANK) = '1' then
            v.hburst(r.hburst'range) := ahbsi.hburst(r.hburst'range);
            v.seq := ahbsi.htrans(0);
            if ahbsi.hwrite = '1' or disable_flash then
              v.hresp := HRESP_ERROR;
              v.hsel := '0';
            else
              if spliten /= 0 then
                if ahbsi.hmastlock = '0' then
                  v.hresp := HRESP_SPLIT;
                  v.splmst := ahbsi.hmaster;
                  v.unsplit := '1';
                else
                  v.ahbcancel := r.insplit;
                end if;
                v.insplit := not ahbsi.hmastlock;
              end if;
            end if;
          end if;
        else
          -- Core is busy, transfer is not locked and access was to flash
          -- area. Respond with SPLIT or insert wait states
          v.hready := '0';
          if spliten /= 0 then
            v.hresp := HRESP_SPLIT;
            v.hsplit(conv_integer(ahbsi.hmaster)) := '1';
          end if;
        end if;
      else
        v.hsel := '0';
      end if;
    end if;

    if (r.hready = '0') then
      if (r.hresp = HRESP_OKAY) then v.hready := '0';
      else v.hresp := r.hresp; end if;
    end if;    
    
    -- Read access to core registers
    if (r.hsel and r.hmbsel(CTRL_BANK) and not r.hwrite) = '1' then
      v.rrdata := (others => '0');
      v.hready := '1';
      v.hsel := '0';
      case regaddr is
        when CONF_REG_OFF =>
          v.rrdata := cslv(readcmd, 8);
        when CTRL_REG_OFF =>
          v.rrdata(3) := r.spio.csn;
          v.rrdata(2) := r.reg.ctrl.eas;
          v.rrdata(1) := r.reg.ctrl.ien;
          v.rrdata(0) := r.reg.ctrl.usrc;
        when STAT_REG_OFF =>
          v.rrdata(2) := '1';
          v.rrdata(1) := r.reg.stat.busy;
          v.rrdata(0) := r.reg.stat.done;
        when RX_REG_OFF => v.rrdata := r.ar(7 downto 0);
        when others => null;
      end case;
    end if;

    -- Write access to core registers
    if (r.hsel and r.hmbsel(CTRL_BANK) and r.hwrite) = '1' then
      case regaddr is
        when CTRL_REG_OFF =>
          v.rst           := hwdata(4);
          if (r.reg.ctrl.usrc and not hwdata(0)) = '1' then
            v.spio.csn := '1';
          elsif hwdata(0) = '1' then
            v.spio.csn := hwdata(3);
          end if;
          v.reg.ctrl.eas  := hwdata(2);
          v.reg.ctrl.ien  := hwdata(1);
          v.reg.ctrl.usrc := hwdata(0);
        when STAT_REG_OFF =>
--          v.spio.errorn := r.spio.errorn or hwdata(3);
          v.reg.stat.done := r.reg.stat.done and not hwdata(0);
        when RX_REG_OFF => null;
        when TX_REG_OFF =>
          if r.reg.ctrl.usrc = '1' then
            v.sreg := hwdata(7 downto 0);
          end if;
        when others => null;
      end case;
    end if;
    
    ---------------------------------------------------------------------------
    -- SPIMCTRL control FSM
    ---------------------------------------------------------------------------
    v.reg.stat.busy := '1';
    
    case r.spimstate is
      when BUSY =>
        -- Wait for core to finish user mode access
        if (r.go or r.spio.sck) = '0' then
          v.spimstate := IDLE;
          v.reg.stat.done:= '1';
          v.irq := r.reg.ctrl.ien;
        end if;
                   
      when AHB_RESPOND =>
        if r.spio.ready = '1' then
          if spliten /= 0 and r.unsplit = '1' then
            hsplit(conv_integer(r.splmst)) := '1';
            v.unsplit := '0';
          end if;
          if ((spliten = 0 or v.ahbcancel = '0') and
              (spliten = 0 or ahbsi.hmaster = r.splmst or r.insplit = '0') and
              (((ahbsi.hsel(hindex) and ahbsi.hready and ahbsi.htrans(1)) = '1') or
               ((spliten = 0 or r.insplit = '0') and r.hready = '0' and r.hresp = HRESP_OKAY))) then
            v.spimstate := IDLE;
            v.hresp := HRESP_OKAY;
            if spliten /= 0 then
              v.insplit := '0';
              v.hsplit := r.hsplit;
            end if;
            v.hready := '1';
            v.hsel := '0';
--             if r.spio.errorn = '0' then
--               v.hready := '0';
--               v.hresp := HRESP_ERROR;
--             end if;
          elsif spliten /= 0 and v.ahbcancel = '1' then
            v.spimstate := IDLE;
            v.ahbcancel := '0';
          end if;
        end if; 
        
      when USER_SPI =>
        if r.bd = '1' then
          v.spimstate := BUSY;
          v.hold := '1';
        end if;

      when others => -- IDLE
        if spliten /= 0 and r.hresp /= HRESP_SPLIT then
          hsplit := r.hsplit;
          v.hsplit := (others => '0');
        end if;
        v.reg.stat.busy := '0';
        if r.hsel = '1' then
          if r.hmbsel(FLASH_BANK) = '1' then
            -- Access to memory mapped flash area
            v.spimstate := AHB_RESPOND;
            read_flash := true;
          elsif regaddr = TX_REG_OFF and (r.hwrite and r.reg.ctrl.usrc) = '1' then
            -- Access to core transmit register
            v.spimstate := USER_SPI;
            v.go := '1';
            v.stop := '1';
            change := '1';
            v.hold := '0';
            if dualoutput = 1 then
              v.spio.mosioen := OUTPUT;  
            end if;
          end if;  
        end if;
    end case;
        
    ---------------------------------------------------------------------------
    -- SPI Flash specific code
    ---------------------------------------------------------------------------
    case r.spi.state is  
      when SPI_READ =>
        if r.go = '0' then
          v.go := '1';
          change := '1';
        end if;
        v.spi.cnt := cslv(SPI_ARG_LEN, r.spi.cnt'length);
        if v.bd = '1' then
          v.sreg := r.ar(23 downto 16);
        end if;
        if r.bd = '1' then
          v.hold := '0';
          v.spi.state := SPI_ADDR;
        end if;

      when SPI_ADDR =>
        if v.bd = '1' then
          v.sreg := r.ar(22 downto 15);
          if dualoutput = 1 then
            if r.spi.cnt = zero32(r.spi.cnt'range) then
              v.spio.mosioen := INPUT;
            end if;
          end if;
        end if;
        if r.bd = '1' then
          if r.spi.cnt = zero32(r.spi.cnt'range) then
            v.spi.state := SPI_DATA;
            v.spi.cnt := calc_spi_cnt(r.spi.hsize);
          else
            v.spi.cnt := r.spi.cnt - 1;
          end if;
        end if;
          
      when SPI_DATA =>
        if v.bd = '1' then
          v.spi.cnt := r.spi.cnt - 1;
        end if;
        if lastbit = '1' and r.spi.cnt = zero32(r.spi.cnt'range) then
          v.stop := r.go;
        end if;
        if (r.go or r.spio.sck) = '0' then
          if r.spi.hburst(0) = '0' then   -- not an incrementing burst
            v.spi.state := SPI_CSWAIT;  -- CSN wait              
            v.spio.csn := '1';
            v.go := '1';
            v.stop := '1';
            v.seq := '1';             -- Make right choice in SPI_CSWAIT
            v.bcnt := "110";
          else
            v.spi.state := SPI_READY;
          end if;
          v.hold := '1';
        end if;
              
      when SPI_READY =>
        v.spio.ready := '1';
        if read_flash then
          v.go := '1';
          if dualoutput = 1 then
            v.bcnt(2) := '0';
          end if;
          if r.spio.csn = '1' then
            -- New access, command and address
            v.go := '0';
            v.spio.csn := '0';
            v.spi.state := SPI_READ;
          elsif r.seq = '1' then
            -- Continuation of burst
            v.spi.state := SPI_DATA;
            v.hold := '0';
          else
            -- Burst ended and new access
            v.stop := '1';
            v.spio.csn := '1';
            v.spi.state := SPI_CSWAIT;
            v.bcnt := "011";
          end if;
          v.ar := (others => '0');
          if offset /= 0 then
            v.ar(r.haddr'range) := r.haddr + cslv(offset, req_addr_bits);
          else
            v.ar(r.haddr'range) := r.haddr;
          end if;
          v.spio.ready := '0';
          v.sreg := cslv(readcmd, 8);
        end if;
        if r.spio.ready = '0' then
          case r.spi.hsize is
            when HSIZE_BYTE =>
              for i in 0 to (MAXDW/8-1) loop
                v.frdata(7+8*i downto 8*i):= r.ar(7 downto 0);
              end loop;  -- i
            when HSIZE_HWORD =>
              for i in 0 to (MAXDW/16-1) loop
                v.frdata(15+16*i downto 16*i) := r.ar(15 downto 0);
              end loop;  -- i
            when HSIZE_WORD =>
              for i in 0 to (MAXDW/32-1) loop
                v.frdata(31+32*i downto 32*i) := r.ar(31 downto 0);
              end loop;  -- i
            when HSIZE_DWORD =>
              if MAXDW > 32 and AHBDW > 32 then
                for i in 0 to (MAXDW/64-1) loop
                  if MAXDW = 64 then
                    v.frdata(MAXDW-1+MAXDW*i downto MAXDW*i) :=
                      r.ar(MAXDW-1 downto 0);
                  elsif MAXDW = 128 then
                    v.frdata(MAXDW/2-1+MAXDW/2*i downto MAXDW/2*i) :=
                      r.ar(MAXDW/2-1 downto 0);
                  else
                    v.frdata(MAXDW/4-1+MAXDW/4*i downto MAXDW/4*i) :=
                      r.ar(MAXDW/4-1 downto 0);
                  end if;
                end loop;  -- i
              else
                null;
              end if;
            when HSIZE_4WORD =>
              if MAXDW > 64 and AHBDW > 64 then
                for i in 0 to (MAXDW/128-1) loop
                  if MAXDW = 128 then
                    v.frdata(MAXDW-1+MAXDW*i downto MAXDW*i) :=
                      r.ar(MAXDW-1 downto 0);
                  else
                    v.frdata(MAXDW/2-1+MAXDW/2*i downto MAXDW/2*i) :=
                      r.ar(MAXDW/2-1 downto 0);
                  end if;
                end loop;  -- i
              else
                null;
              end if;
            when others =>
              if MAXDW > 128 and AHBDW > 128 then
                v.frdata := r.ar;
              else
                null;
              end if;
          end case;
        end if;
        v.spi.hsize := r.hsize;
        v.spi.hburst(0) := r.hburst(0);
        v.spi.cnt := calc_spi_cnt(r.spi.hsize);
          
      when others => -- SPI_CSWAIT
        v.hold := '1';
        -- Chip select wait
        if (r.go or r.spio.sck) = '0' then
          if r.seq = '1' then
            v.spi.state := SPI_READY;
          else
            v.spi.state := SPI_READ;
            v.spio.csn := '0';
          end if;
          if dualoutput = 1 then
            v.spio.mosioen := OUTPUT;
            v.bcnt(2) := '0';
          end if;
        end if;
    end case;

    ---------------------------------------------------------------------------
    -- SPI communication
    ---------------------------------------------------------------------------
    -- Clock generation
    if (r.go or r.spio.sck) = '1' then
      v.timer := r.timer - 1;
      if sck_toggle(v.timer, r.timer, enable_altscaler) then
        v.spio.sck := not r.spio.sck;
        v.sample(0) := not r.spio.sck;
        change := r.spio.sck and r.go;
        if (v.stop and lastbit and not r.spio.sck) = '1' then
          v.go := '0';
          v.stop := '0';
        end if;
      end if;
    else
      v.timer := (others => '1');
    end if;

    if r.sample(0) = '1' then
      v.bcnt := r.bcnt + 1;
    end if;
    
    if r.sample(1) = '1' then
      if r.hold = '0' then
        if dualoutput = 1 and r.spio.mosioen = INPUT then
          v.ar := r.ar(r.ar'left-2 downto 0) & r.spii(1).miso & r.spii(1).mosi;
        else
          v.ar := r.ar(r.ar'left-1 downto 0) & r.spii(1).miso;
        end if;
      end if;
    end if;
    
    if change = '1' then
      v.spio.mosi := v.sreg(7);
      if r.spi.state /= SPI_CSWAIT then
        v.sreg(7 downto 0) := v.sreg(6 downto 0) & '1';
      end if;
    end if;
    
    ---------------------------------------------------------------------------
    -- System and core reset
    ---------------------------------------------------------------------------
    if (not rstn or r.rst) = '1' then
      v.spi.state        := SPI_READY;
      v.frdata           := (others => '0'); 
      v.spio.cdcsnoen    := OUTPUT;
      v.spimstate        := IDLE;
      v.rst              := '0';
      --
      v.reg.ctrl         := ('0', '0', '0');
      v.reg.stat.done    := '0';
      --
      v.sample           := (others => '0');
      v.sreg             := (others => '1');
      v.bcnt             := (others => '0');
      v.go               := '0';
      v.stop             := '0';
      v.hold             := '1';
      v.unsplit          := '0';
      --
      v.hready           := '1';
      v.hwrite           := '0';
      v.hsel             := '0';
      v.hmbsel           := (others => '0');
      v.ahbcancel        := '0';
      --
      v.spio.sck         := '0';
      v.spio.mosi        := '1';
      v.spio.mosioen     := OUTPUT;
      v.spio.csn         := '1';
--       v.spio.errorn      := '1';
      v.spio.ready       := '0';      
    end if;
    v.spio.initialized := '1';
    
    ---------------------------------------------------------------------------
    -- Drive unused signals
    ---------------------------------------------------------------------------
    if spliten = 0 then
      v.insplit   := '0';
      v.unsplit   := '0';
      v.splmst    := (others => '0');
      v.hsplit    := (others => '0');
      v.ahbcancel := '0';
    end if;
    
    ---------------------------------------------------------------------------
    -- Signal assignments
    ---------------------------------------------------------------------------    
    -- Core registers
    rin <= v;

    -- AHB slave output
    ahbso.hready  <= r.hready;
    ahbso.hresp   <= r.hresp;
    if r.hmbsel(CTRL_BANK) = '1' then
      for i in 0 to (MAXDW/32-1) loop 
        hrdata(31 + 32*i downto 32*i) := zero32(31 downto 8) & r.rrdata;
      end loop;
    else
      hrdata := r.frdata;
    end if;
    ahbso.hrdata  <= ahbdrivedata(hrdata);
    ahbso.hconfig <= HCONFIG;
    ahbso.hirq    <= ahbirq;
    ahbso.hindex  <= hindex;
    ahbso.hsplit  <= hsplit;

    -- SPI signals
    spio <= r.spio;
  end process comb;

  reg: process (clk)
  begin  -- process reg
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process reg;

  -- Boot message
  -- pragma translate_off
  bootmsg : report_version 
    generic map (
      "spimctrl" & tost(hindex) & ": SPI memory controller rev " &
      tost(REVISION) & ", irq " & tost(hirq));
  -- pragma translate_on
  
-- pragma translate_off
   assert ahbsi.endian /= '1'
      report "spimctrl: little endian systems not supported"
      severity error;
-- pragma translate_on

end rtl;
