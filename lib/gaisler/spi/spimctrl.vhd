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
-------------------------------------------------------------------------------
-- Entity:      spimctrl
-- File:        spimctrl.vhd
-- Author:      Jan Andersson - Frontgrade Gaisler AB
--              support@gaisler.com
-- Modified:    Axel Karlsson - Frontgrade Gaisler AB
--              support@gaisler.com
--
-- Description: SPI flash memory controller. Supports a wide range of SPI
--              memory devices with the data read instruction configurable via
--              generics.
-- 
-- The controller has two memory areas. The flash area where the flash memory
-- is directly mapped and the I/O area where core registers are mapped.
--
-- Revision 1 added support for burst reads when sdcard = 0
--
-- Post revision 1: Remove support for SD card
--
-- Revision 2 added support for DSPI/QSPI & 4-byte addressing
-- 
-- Revision 3. No new updates. There were a collision in the revision number for different 
-- versions of the SPIMCTRL. Both the GRLIB and GR716B had revision number 2 but were seperate
-- incompatible implementations of the IP. For clarity the GRLIB version has been changed
-- to revision #3 and the GR716B is kept as revision #2.
--
-- Revision 4. Support for multiple memory devices added. Behaviour for when writing to the
-- ROM area is allowed slightly changed. Can now be controlled with a register bit during
-- runtime instead of purely statically through a VHDL generic.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
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
    hindex       : integer := 0;            -- AHB slave index
    hirq         : integer := 0;            -- Interrupt line
    faddr        : integer := 16#000#;      -- Flash map base address
    fmask        : integer := 16#fff#;      -- Flash area mask
    ioaddr       : integer := 16#000#;      -- I/O base address
    iomask       : integer := 16#fff#;      -- I/O mask
    spliten      : integer := 0;            -- AMBA SPLIT support
    oepol        : integer := 0;            -- Output enable polarity
    sdcard       : integer range 0 to 0   := 0;  -- Unused
    readcmd      : integer range 0 to 255 := 16#0B#;  -- Mem. dev. READ command
    dummybyte    : integer range 0 to 1   := 1;  -- Dummy byte after cmd (8 cycles)
    dualoutput   : integer range 0 to 1   := 0;  -- Enable dual output (Data phase)
    scaler       : integer range 1 to 512 := 1; -- SCK scaler
    altscaler    : integer range 1 to 512 := 1; -- Alternate SCK scaler
    pwrupcnt     : integer  := 0;               -- Unused
    maxahbaccsz  : integer range 0 to 256 := AHBDW; -- Max AHB access size
    offset       : integer := 0;
    quadoutput   : integer range 0 to 1   := 0;  -- Enable quad output (Data phase)
    dualinput    : integer range 0 to 1   := 0;  -- Enable dual input (Addr phase)
    quadinput    : integer range 0 to 1   := 0;  -- Enable quad input (Addr phase)
    dummycycles  : integer range 0 to 15  := 0;  -- # dummy cycles after cmd (not used if dummybyte=1)
    DSPI         : integer range 0 to 1   := 0;  -- Full Dual SPI mode (all transactins 2-2-2)
    QSPI         : integer range 0 to 1   := 0;  -- Full Quad SPI mode (all transactins 4-4-4)
    extaddr      : integer range 0 to 2   := 0;  -- Extended address mode (0=>3-Bytes, 1=>4-Bytes, 2=>use bootstrap signal rstaddrm to determine mode)
    reconf       : integer range 0 to 1   := 0;  -- Enables changing configuration through reg. interface
    writecmd     : integer range 0 to 255 := 16#02#; -- Mem. dev. write command
    allow_writes : integer range 0 to 1   := 0;  -- Determines if writes are allowed to the flash area (else error response)
    xip_byte     : integer range 0 to 1   := 0;  -- Send XIP byte after address phase
    xip_polarity : integer range 0 to 1   := 1;  -- Value shifted into the memory in the xip byte and dummy cycles phase
    multiple_csn : integer range 0 to 1   := 0   -- Allow the use of chip select signals 1-3
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
  
  constant REVISION : amba_version_type := 4;

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

  -- Default address length in bytes - 1 
  constant SPI_ADDR_LENGTH : integer := 2;
  -- Number of dummy cycles to use for the dummybyte setting
  constant SPI_DUMMY_BYTE_CYCLES : integer := 8;

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
  constant CTRL2_REG_OFF : std_logic_vector(7 downto 2) := "000111";
  
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
  
  -- Description: Determines the polarity of the bit shifted to memory device during
  -- xip byte and dummy cycles phase.
  function bit_pol
    return std_ulogic is
    begin
      if xip_polarity /= 0 then 
        return '1';
      end if;
      return '0';
    end bit_pol;

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

  function to_ulogic (
    i : integer range 0 to 1
  )
  return std_ulogic is
  begin
    if i = 0 then
      return '0';
    else
      return '1';
    end if;
  end to_ulogic;

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

  -- Description: Swap the order of bytes to account for endianness
  function spimctrl_endian_swap(
    data : std_logic_vector;
    endian : std_ulogic)
    return std_logic_vector is
    variable tmp : std_logic_vector(data'length-1 downto 0) := data(data'length-1 downto 0);
  begin
    if endian = '1' then
      -- Little endian
      for i in 0 to data'length/8-1 loop
        tmp(data'length-8*i-1 downto data'length-8*(i+1)) := data(8*(i+1)-1 downto 8*i);
      end loop;

      return tmp;
    else
      -- Big endian

      return tmp;
    end if;
  end spimctrl_endian_swap;


  -----------------------------------------------------------------------------
  -- States
  -----------------------------------------------------------------------------

  -- Main FSM states
  type spimstate_type is (IDLE, AHB_RESPOND, USER_SPI, BUSY);
  
  -- SPI device FSM states
 type spistate_type is (SPI_CSWAIT,  SPI_READY, SPI_READ, SPI_ADDR, SPI_DATA, SPI_DUMMY);
  
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
  constant spiflash_none : spiflash_type := (SPI_READY, "00000", "000", "0");

  type spimctrl_in_array is array (1 downto 0) of spimctrl_in_type;
  
  type spim_reg_type is record
       -- Common
       spimstate      : spimstate_type;  -- Main FSM
       rst            : std_ulogic;      -- Reset
       reg            : spim_regif_type; -- Register bank
       timer          : std_logic_vector((timer_size-1) downto 0);
       sample         : std_logic_vector(2 downto 0);  -- Sample data line
       bd             : std_logic_vector(1 downto 0);
       sreg           : std_logic_vector(7 downto 0);  -- Shiftreg
       bcnt           : std_logic_vector(2 downto 0);  -- Bit counter
       go             : std_ulogic;     -- SPI comm. active
       stop           : std_ulogic;     -- Stop SPI comm.
       ar             : std_logic_vector(MAXDW-1 downto 0); -- argument/response
       hold           : std_ulogic;     -- Do not shift ar
       insplit        : std_ulogic;     -- SPLIT response issued
       unsplit        : std_ulogic;     -- SPLIT complete not issued
       csn            : std_ulogic;     -- Combined chip select signal for both SPI memories
       ds             : std_logic_vector(1 downto 0);
       --
       readcmd        : std_logic_vector(7 downto 0); -- Mem. dev. READ command
       writecmd       : std_logic_vector(7 downto 0); -- Mem. dev. WRITE command
       dualoutput     : std_ulogic;     -- Dual mode in data phase on reads
       quadoutput     : std_ulogic;     -- Quad mode in data phase on reads
       dualinput      : std_ulogic;     -- Dual mode in address phase on reads
       quadinput      : std_ulogic;     -- Quad mode in address phase on reads
       dummybyte      : std_ulogic;     -- Dummy byte after cmd (8 cycles)
       dummycycles    : std_logic_vector(3 downto 0); -- # dummy cylcles after cmd
       DSPI           : std_ulogic;     -- Full Dual SPI mode (all transactins 2-2-2)
       QSPI           : std_ulogic;     -- Full Quad SPI mode (all transactins 4-4-4)
       extaddr        : std_ulogic;     -- Extended address mode (0 -> 3 Bytes, 1 -> 4 Bytes)
       xip_byte       : std_ulogic;     -- Write XIP (disable) byte after address phase.
       allow_writes   : std_ulogic;     -- Determines if writes are allowed or not (error response) to the flash area
       dsconf         : std_logic_vector(3 downto 0); -- chip select split configuration
       -- SPI flash device
       spi            : spiflash_type;
       -- AHB
       irq            : std_ulogic;     -- Interrupt request
       hsize          : std_logic_vector(2 downto 0);
       hwrite         : std_ulogic;
       hsel           : std_ulogic;
       hmbsel         : std_logic_vector(0 to 1);
       haddr          : std_logic_vector(31 downto 0);
       hwdata         : std_logic_vector(MAXDW-1 downto 0);
       hready         : std_ulogic;
       frdata         : std_logic_vector(MAXDW-1 downto 0);  -- Flash response data
       rrdata         : std_logic_vector(31 downto 0);  -- Register response data
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
  
  -- Description: Returns in what output mode the the SPIMCTRL should operate.
  -- 0=serial, 1=dual, 2=quad
  function getOutputMode(
    r       : spim_reg_type
  ) 
  return integer is 
    begin
      if r.QSPI = '1' or (r.DSPI = '0' and r.quadoutput = '1') then
        return 2;
      elsif r.DSPI = '1' or r.dualoutput = '1' then
        return 1;
      else 
        return 0;
      end if;
    end getOutputMode;

  -- Description: Returns in what input mode the the SPIMCTRL should operate.
  -- 0=serial, 1=dual, 2=quad
  function getInputMode(
    r       : spim_reg_type
  ) 
  return integer is 
    begin
      if r.QSPI = '1' or (r.DSPI = '0' and r.quadinput = '1') then
        return 2;
      elsif r.DSPI = '1' or r.dualinput = '1' then
        return 1;
      else 
        return 0;
      end if;
    end getInputMode;

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  
  signal r, rin : spim_reg_type;
  
begin  -- rtl

  comb: process (r, rstn, ahbsi, spii)
    variable v                : spim_reg_type;
    variable change           : std_ulogic;
    variable regaddr          : std_logic_vector(7 downto 2);
    variable lowaddr          : std_logic_vector(1 downto 0);
    variable hsplit           : std_logic_vector(NAHBMST-1 downto 0);
    variable ahbirq           : std_logic_vector((NAHBIRQ-1) downto 0);
    variable lastbit          : std_ulogic;
    variable enable_altscaler : boolean;
    variable disable_flash    : boolean;
    variable read_flash       : boolean;
    variable hrdata           : std_logic_vector(MAXDW-1 downto 0);
    variable hwdatax          : std_logic_vector(31 downto 0);
    variable samplecmp        : std_logic_vector(1 downto 0);
    variable addr             : std_logic_vector(31 downto 0);
    variable csn_mask         : std_logic_vector(31 downto 0);
    variable ds               : std_logic_vector(1 downto 0);
    
  begin  -- process comb

    v := r; v.spii := r.spii(0) & spii; v.sample := r.sample(1 downto 0) & '0';
    change := '0'; v.irq := '0'; v.hresp := HRESP_OKAY; v.hready := '1'; v.bd := r.bd(0) & '0';
    regaddr := r.haddr(7 downto 2); hsplit := (others => '0');
    lowaddr := r.haddr(1 downto 0);
    hwdatax := ahbreadword(ahbsi.hwdata, r.haddr(4 downto 2), conv_integer(ahbsi.endian));
    ahbirq := (others => '0'); ahbirq(hirq) := r.irq;
    read_flash := false;
    enable_altscaler := r.reg.ctrl.eas = '1';
    disable_flash := (r.reg.ctrl.usrc = '1' or r.spimstate = USER_SPI);

    if ((r.spimstate = USER_SPI or r.spi.state = SPI_READ)  and r.QSPI = '1') or 
       (r.spi.state = SPI_ADDR and getInputMode(r) = 2) or
       (r.spi.state = SPI_DATA and getOutputMode(r) = 2)  then
      lastbit := r.bcnt(0);

    elsif ((r.spimstate = USER_SPI or r.spi.state = SPI_READ)  and r.DSPI = '1') or 
          (r.spi.state = SPI_ADDR and getInputMode(r) = 1) or
          (r.spi.state = SPI_DATA and getOutputMode(r) = 1)  then
      lastbit := andv(r.bcnt(1 downto 0));
    else 
      lastbit := andv(r.bcnt);
    end if;
    v.bd(0) := lastbit and r.sample(0); 

    if r.spimstate = IDLE then
      v.spio.io2 := '1';
      v.spio.io3 := '1';
    end if;

    -- 'Device Select' logic 
    csn_mask := (others => '1');
    if r.reg.ctrl.usrc = '0' then 
      case r.dsconf is 
        when "0000" => ds := "00";                                                             -- Always use SPIM0
        when "0001" => ds := "01";                                                             -- Always use SPIM1
        when "0010" => ds := "10";                                                             -- Always use SPIM2
        when "0011" => ds := "11";                                                             -- Always use SPIM3
        when "0100" => ds := r.haddr(18 downto 17); csn_mask(31 downto 17) := (others => '0'); -- 128 KiB
        when "0101" => ds := r.haddr(19 downto 18); csn_mask(31 downto 18) := (others => '0'); -- 256 KiB
        when "0110" => ds := r.haddr(20 downto 19); csn_mask(31 downto 19) := (others => '0'); -- 512 KiB
        when "0111" => ds := r.haddr(21 downto 20); csn_mask(31 downto 20) := (others => '0'); -- 1 MiB
        when "1000" => ds := r.haddr(22 downto 21); csn_mask(31 downto 21) := (others => '0'); -- 2 MiB
        when "1001" => ds := r.haddr(23 downto 22); csn_mask(31 downto 22) := (others => '0'); -- 4 MiB
        when "1010" => ds := r.haddr(24 downto 23); csn_mask(31 downto 23) := (others => '0'); -- 8 MiB
        when "1011" => ds := r.haddr(25 downto 24); csn_mask(31 downto 24) := (others => '0'); -- 16 MiB
        when "1100" => ds := r.haddr(26 downto 25); csn_mask(31 downto 25) := (others => '0'); -- 32 MiB
        when "1101" => ds := r.haddr(27 downto 26); csn_mask(31 downto 26) := (others => '0'); -- 64 MiB
        when "1110" => ds := r.haddr(28 downto 27); csn_mask(31 downto 27) := (others => '0'); -- 128 MiB
        when others => ds := r.haddr(29 downto 28); csn_mask(31 downto 28) := (others => '0'); -- 256 MiB
      end case;
    else
      ds := r.ds;
    end if;
    
    if multiple_csn = 0 then
      ds       := "00";
      csn_mask := (others => '1');
    end if;
    
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
          v.haddr(req_addr_bits-1 downto 0) := ahbsi.haddr(req_addr_bits-1 downto 0);
          v.hsel := '1';
          if ahbsi.hmbsel(FLASH_BANK) = '1' then
            v.hburst(r.hburst'range) := ahbsi.hburst(r.hburst'range);
            v.seq := ahbsi.htrans(0);
            if (r.allow_writes='0' and ahbsi.hwrite = '1') or disable_flash then
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
          v.rrdata(READCMD_RANGE)     := r.readcmd;
          v.rrdata(DUMMYCYCLES_RANGE) := r.dummycycles;
          v.rrdata(DSPI_INDEX)        := r.DSPI;
          v.rrdata(QSPI_INDEX)        := r.QSPI;
          v.rrdata(EXTADDR_INDEX)     := r.extaddr;
          v.rrdata(DUMMYBYTE_INDEX)   := r.dummybyte;
          v.rrdata(DUALOUT_INDEX)     := r.dualoutput;
          v.rrdata(QUADOUT_INDEX)     := r.quadoutput;
          v.rrdata(DUALIN_INDEX)      := r.dualinput;
          v.rrdata(QUADIN_INDEX)      := r.quadinput;
          v.rrdata(XIP_INDEX)         := r.xip_byte;
          v.rrdata(WRITECMD_RANGE)    := r.writecmd;
        when CTRL_REG_OFF =>
          v.rrdata(6 downto 5) := r.ds;
          v.rrdata(3) := r.csn;
          v.rrdata(2) := r.reg.ctrl.eas;
          v.rrdata(1) := r.reg.ctrl.ien;
          v.rrdata(0) := r.reg.ctrl.usrc;
        when STAT_REG_OFF =>
          v.rrdata(8) := to_ulogic(multiple_csn);
          v.rrdata(7) := to_ulogic(allow_writes);
          v.rrdata(6) := to_ulogic(reconf);
          v.rrdata(2) := '1';
          v.rrdata(1) := r.reg.stat.busy;
          v.rrdata(0) := r.reg.stat.done;
        when RX_REG_OFF => 
          v.rrdata(7 downto 0) := r.ar(7 downto 0);
        when CTRL2_REG_OFF => 
          v.rrdata(3 downto 0) := r.dsconf;
          v.rrdata(4)          := r.allow_writes;
        when others => null;
      end case;
    end if;

    -- Write access to core registers
    if (r.hsel and r.hmbsel(CTRL_BANK) and r.hwrite) = '1' then
      case regaddr is
        when CONF_REG_OFF =>
        if reconf = 1 then
          v.readcmd     := hwdatax(READCMD_RANGE);
          v.dummycycles := hwdatax(DUMMYCYCLES_RANGE);
          v.DSPI        := hwdatax(DSPI_INDEX);
          v.QSPI        := hwdatax(QSPI_INDEX);
          v.extaddr     := hwdatax(EXTADDR_INDEX);
          v.dummybyte   := hwdatax(DUMMYBYTE_INDEX);
          v.dualoutput  := hwdatax(DUALOUT_INDEX);
          v.quadoutput  := hwdatax(QUADOUT_INDEX);
          v.dualinput   := hwdatax(DUALIN_INDEX);
          v.quadinput   := hwdatax(QUADIN_INDEX);
          v.xip_byte    := hwdatax(XIP_INDEX);
          v.writecmd    := hwdatax(WRITECMD_RANGE);
        end if;
        when CTRL_REG_OFF =>
          if multiple_csn /= 0 then 
            v.ds := hwdatax(6 downto 5);
          end if;
          
          v.rst := hwdatax(4);
          if (r.reg.ctrl.usrc and not hwdatax(0)) = '1' then
            v.csn := '1';
          elsif hwdatax(0) = '1' then
            v.csn := hwdatax(3);
          end if;
          v.reg.ctrl.eas  := hwdatax(2);
          v.reg.ctrl.ien  := hwdatax(1);
          v.reg.ctrl.usrc := hwdatax(0);
        when STAT_REG_OFF =>
          v.reg.stat.done := r.reg.stat.done and not hwdatax(0);
        when RX_REG_OFF => 
          v.sreg := (others => '0');
        when TX_REG_OFF =>
          if r.reg.ctrl.usrc = '1' then
            v.sreg := hwdatax(7 downto 0);
          end if;
        when CTRL2_REG_OFF =>
          if multiple_csn /= 0 then
            v.dsconf := hwdatax(3 downto 0);
          end if;
          v.allow_writes := hwdatax(4);
        when others => null;
      end case;
    end if;
    
    -- Write access to memory area 
    if (r.hsel and r.hmbsel(FLASH_BANK) and r.hwrite) = '1' then
      -- Select correct data depending on hsize
      v.hwdata := ahbselectdata(ahbsi.hwdata, r.haddr(4 downto 2), r.hsize, conv_integer(ahbsi.endian));
      
      -- Do endian byte swap
      v.hwdata := spimctrl_endian_swap(v.hwdata, ahbsi.endian);
      
      -- ahbselectdata only works for 256-32 bit accesses.
      -- Need to select correct data in 8 & 16 bit case:
      if r.hsize = "001" then
        -- 16b
        if r.haddr(1)='0' then
          v.hwdata := ahbdrivedata(v.hwdata(31 downto 16));
        else
          v.hwdata := ahbdrivedata(v.hwdata(15 downto 0));
        end if;
      elsif r.hsize = "000" then
        -- 8b
        case lowaddr is
          when "00"   => v.hwdata := ahbdrivedata(v.hwdata(31 downto 24));
          when "01"   => v.hwdata := ahbdrivedata(v.hwdata(23 downto 16));
          when "10"   => v.hwdata := ahbdrivedata(v.hwdata(15 downto 8));
          when others => v.hwdata := ahbdrivedata(v.hwdata(7 downto 0));
        end case;
      end if;
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
              (((ahbsi.hsel(hindex) and ahbsi.hready and ahbsi.htrans(1)) = '1') 
              or ((spliten = 0 or r.insplit = '0') and r.hready = '0' and r.hresp = HRESP_OKAY))) then
            v.spimstate := IDLE;
            v.hresp := HRESP_OKAY;
            if spliten /= 0 then
              v.insplit := '0';
              v.hsplit := r.hsplit;
            end if;
            v.hready := '1';
            v.hsel := '0';
          elsif spliten /= 0 and v.ahbcancel = '1' then
            v.spimstate := IDLE;
            v.ahbcancel := '0';
          end if;
        end if; 
        
      when USER_SPI =>
        if r.bd(1) = '1' then
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
            -- Sends 8 bits to the flash memory
            v.spimstate := USER_SPI;
            v.go := '1';
            v.stop := '1';
            change := '1';
            v.hold := '0';
            v.bcnt := "000";

            v.spio.misooen := INPUT;
            v.spio.mosioen := OUTPUT;
            if r.DSPI = '1' or r.QSPI = '1' then
              v.spio.misooen := OUTPUT;
              v.bcnt := "100";
              if r.QSPI = '1' then
                v.spio.iooen := OUTPUT;
                v.bcnt := "110";
              end if;
            end if;

          elsif regaddr = RX_REG_OFF and (r.hwrite and r.reg.ctrl.usrc) = '1' then
            -- Access to core receive register
            -- Reads 8 bits from flash memory and saves it in the RX register
            v.spimstate := USER_SPI;
            v.go := '1';
            v.stop := '1';
            change := '1';
            v.hold := '0';
            v.bcnt := "000";

            v.spio.misooen := INPUT;
            if r.DSPI = '1' or r.QSPI = '1' then
              v.spio.mosioen := INPUT;
              v.bcnt := "100";
              if r.QSPI = '1' then
                v.spio.iooen := INPUT;
                v.bcnt := "110";
              end if;
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
        v.spi.cnt := cslv(SPI_ADDR_LENGTH + conv_integer(r.extaddr) + conv_integer(r.xip_byte), r.spi.cnt'length);
        if v.bd(0) = '1' then
          -- Read command have been sent, prepare for address phase
          if r.extaddr = '1' then
            v.sreg := r.ar((23+8) downto (16 + 8));
          else
            v.sreg := r.ar(23 downto 16);
          end if;
          v.spio.mosioen := OUTPUT;
          if getInputMode(r) > 0 then
            v.spio.misooen := OUTPUT;
            if getInputMode(r) = 2 then 
              v.spio.iooen := OUTPUT;
            end if;
          end if;
          
          v.hold := '0';
        end if;
        if r.bd(0) = '1' then
          v.hold := '0';
          v.spi.state := SPI_ADDR;
        end if;

      when SPI_ADDR =>
        if v.bd(0) = '1' then
          if r.extaddr = '0' then
            v.sreg := r.ar(23 downto 16);
          else
            v.sreg := r.ar(31 downto 24);
          end if;

          if r.spi.cnt = zero32(r.spi.cnt'range) and ((r.dummybyte = '0' and r.dummycycles = "0000") or r.hwrite = '1') then
            
            v.spio.misooen := INPUT;
            v.spio.mosioen := OUTPUT;
            v.spio.iooen   := OUTPUT;
            
            if r.hwrite = '1' then 
              -- Set ar and sreg registers to use the write data
              v.ar   := r.hwdata;
              v.sreg := r.hwdata(r.hwdata'length-1 downto r.hwdata'length-8);
              if getOutputMode(r) > 0 then
                v.spio.misooen := OUTPUT;
                if getOutputMode(r) = 2 then
                  v.spio.iooen := OUTPUT;
                end if;
              end if;
            else
              if getOutputMode(r) > 0 then
                v.spio.mosioen := INPUT;
                if getOutputMode(r) = 2 then
                  v.spio.iooen := INPUT;
                end if;
              end if;
            end if;
          end if;
          
        end if;
        if r.bd(0) = '1' then 
          if r.spi.cnt = zero32(r.spi.cnt'range) then
            if (r.dummybyte = '0' and r.dummycycles = "0000") or r.hwrite = '1' then
              v.spi.state := SPI_DATA;
              v.spi.cnt := calc_spi_cnt(r.spi.hsize);
              v.sample := (others => '0');
            else 
              v.spi.state := SPI_DUMMY;
              v.hold := '1';
              if r.dummybyte = '1' then
                v.spi.cnt(3 downto 0) := cslv(SPI_DUMMY_BYTE_CYCLES, 4);
              else
                v.spi.cnt(3 downto 0) := r.dummycycles;
              end if;
            end if;
          else
            v.spi.cnt := r.spi.cnt - 1;
          end if;
        end if;

      when SPI_DUMMY =>
        if r.sample(0) = '1' then
          v.spi.cnt := r.spi.cnt - 1;
        end if;
        if r.spi.cnt = zero32(r.spi.cnt'range) then
          v.spi.state := SPI_DATA;
          v.spi.cnt := calc_spi_cnt(r.spi.hsize);
          v.sample := (others => '0');
          v.hold := '0';
          v.bcnt := "000";
        elsif r.spi.cnt = cslv(1, r.spi.cnt'length) then
          -- Set -oen values the clock cycle before leaving dummy phase
          v.spio.misooen := INPUT;
          v.spio.mosioen := OUTPUT;
          v.spio.iooen   := OUTPUT;
          if getOutputMode(r) > 0 then
            v.spio.mosioen := INPUT;
            if getOutputMode(r) = 2 then
              v.spio.iooen := INPUT;
            end if;
          end if;
        end if;
          
      when SPI_DATA =>
        if v.bd(0) = '1' then
          v.spi.cnt := r.spi.cnt - 1;
          -- Update sreg with data from ar (used for memory writes)
          v.sreg := r.ar(AHBDW-1 downto AHBDW-8);
        end if;
        if lastbit = '1' and r.spi.cnt = zero32(r.spi.cnt'range) then
          v.stop := r.go;
        end if;
        if (r.go or r.spio.sck) = '0' and r.bd ="00" then
          if r.spi.hburst(0) = '0' then   -- not an incrementing burst
            v.spi.state := SPI_CSWAIT;  -- CSN wait              
            v.csn := '1';
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
          if getOutputMode(r) > 0 then
            v.bcnt(2) := '0';
          end if;
          if r.csn = '1' then
            -- New access, command and address
            v.go := '0';
            v.csn := '0';
            v.spi.state := SPI_READ;
            
            v.spio.misooen := INPUT;
            v.spio.mosioen := OUTPUT;
            v.spio.iooen   := OUTPUT;
            if r.DSPI = '1' or r.QSPI = '1' then
              v.spio.misooen := OUTPUT;
            end if;

          elsif r.seq = '1' then
            -- Continuation of burst
            v.spi.state := SPI_DATA;
            v.hold := '0';
            
            if r.hwrite = '1' then 
              -- Set ar and sreg registers to use the write data
              v.ar   := v.hwdata;
              v.sreg := v.ar(v.ar'length-1 downto v.ar'length-8);
              change := '1';
              -- Need to trigger sample(1) so AR is shifted and data is not out of sync
              v.sample(1) := '1';
              -- Set io-en values
              v.spio.misooen := INPUT;
              v.spio.mosioen := OUTPUT;
              v.spio.iooen   := OUTPUT;
              if getOutputMode(r) > 0 then
                v.spio.misooen := OUTPUT;
                if getOutputMode(r) = 2 then
                  v.spio.iooen := OUTPUT;
                end if;
              end if;
            else
              v.spio.misooen := INPUT;
              v.spio.mosioen := OUTPUT;
              v.spio.iooen   := OUTPUT;
              if getOutputMode(r) > 0 then
                v.spio.mosioen := INPUT;
                if getOutputMode(r) = 2 then
                  v.spio.iooen := INPUT;
                end if;
              end if;
            end if;
            
          else
            -- Burst ended and new access
            v.spi.state := SPI_CSWAIT;
            v.csn := '1';
            v.stop := '1';
            v.bcnt := "011";
          end if;

          v.spio.ready := '0';
          
          if (r.csn = '1') or (r.seq = '0') then
            -- New access. Set command and address of incoming access
            v.ar := (others => '0');
            addr := r.haddr;
            addr := addr and csn_mask;
            if offset /= 0 then
              addr(r.haddr'range) := addr + cslv(offset, req_addr_bits);
            end if;
            v.ar(31 downto 0) := addr;
            
            if r.hwrite = '0' then
              v.sreg := r.readcmd;
            else
              v.sreg := r.writecmd;
            end if;
          end if;

        end if;
        if r.spio.ready = '0' then
          case r.spi.hsize is
            when HSIZE_BYTE =>
              for i in 0 to (MAXDW/8-1) loop
                v.frdata(7+8*i downto 8*i):= r.ar(7 downto 0);
              end loop;  -- i
            when HSIZE_HWORD =>
              for i in 0 to (MAXDW/16-1) loop
                v.frdata(15+16*i downto 16*i) := spimctrl_endian_swap(r.ar(15 downto 0), ahbsi.endian);
              end loop;  -- i
            when HSIZE_WORD =>
              for i in 0 to (MAXDW/32-1) loop
                v.frdata(31+32*i downto 32*i) := spimctrl_endian_swap(r.ar(31 downto 0), ahbsi.endian);
              end loop;  -- i
            when HSIZE_DWORD =>
              if MAXDW > 32 and AHBDW > 32 then
                for i in 0 to (MAXDW/64-1) loop
                  --if MAXDW = 64 then
                  --  v.frdata(MAXDW-1+MAXDW*i downto MAXDW*i) :=
                  --  spimctrl_endian_swap(r.ar(MAXDW-1 downto 0));
                  --elsif MAXDW = 128 then
                  --  v.frdata(MAXDW/2-1+MAXDW/2*i downto MAXDW/2*i) :=
                  --  spimctrl_endian_swap(r.ar(MAXDW/2-1 downto 0));
                  --else
                  --  v.frdata(MAXDW/4-1+MAXDW/4*i downto MAXDW/4*i) :=
                  --  spimctrl_endian_swap(r.ar(MAXDW/4-1 downto 0));
                  --end if;
                  v.frdata(63+64*i downto 64*i) := spimctrl_endian_swap(r.ar(63 downto 0), ahbsi.endian);
                end loop;  -- i
              else
                null;
              end if;
            when HSIZE_4WORD =>
              if MAXDW > 64 and AHBDW > 64 then
                for i in 0 to (MAXDW/128-1) loop
                  --if MAXDW = 128 then
                  --  v.frdata(MAXDW-1+MAXDW*i downto MAXDW*i) :=
                  --    r.ar(MAXDW-1 downto 0);
                  --else
                  --  v.frdata(MAXDW/2-1+MAXDW/2*i downto MAXDW/2*i) :=
                  --    r.ar(MAXDW/2-1 downto 0);
                  --end if;
                  v.frdata(127+128*i downto 128*i) := spimctrl_endian_swap(r.ar(127 downto 0), ahbsi.endian);
                end loop;  -- i
              else
                null;
              end if;
            when others =>
              if MAXDW > 128 and AHBDW > 128 then
                v.frdata := spimctrl_endian_swap(r.ar, ahbsi.endian);
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
            v.csn := '0';
            v.spio.misooen := INPUT;
            v.spio.mosioen := OUTPUT;
            v.spio.iooen   := OUTPUT;
            if r.DSPI = '1' or r.QSPI = '1' then
              v.spio.misooen := OUTPUT;
              if r.QSPI = '1' then
                v.spio.iooen := OUTPUT;
              end if;
            end if;

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
      v.timer := (others => '0');
    end if;

    if r.sample(0) = '1' then
      v.bcnt := r.bcnt + 1;
    end if;
    
    -- Use different timings for when to Shift AR depending if we are reading or writing
    -- to the SPI memory. Reading should wait one more cycle so the data is ready in
    -- r.spii(1) (which is a Two flip-flop synchronizer)
    if ((r.spi.state = SPI_DATA) and (r.hwrite = '0')) or r.spimstate = USER_SPI then
      samplecmp := "10";
    else
      samplecmp := "01";
    end if;
    
    if r.sample(2 downto 1) = samplecmp then
      if r.hold = '0' then

        -- Shift ar register if in CMD or ADDR phase
        if ((r.spimstate = USER_SPI or r.spi.state = SPI_READ)  and r.QSPI = '1' and r.spio.mosioen = OUTPUT) or 
           (v.spi.state = SPI_ADDR and getInputMode(r) = 2) then
          v.ar := r.ar(r.ar'left-4 downto 0) & bit_pol & bit_pol & bit_pol & bit_pol;

        elsif ((r.spimstate = USER_SPI or r.spi.state = SPI_READ)  and r.DSPI = '1' and r.spio.mosioen = OUTPUT) or 
              (v.spi.state = SPI_ADDR and getInputMode(r) = 1) then
          v.ar := r.ar(r.ar'left-2 downto 0) & bit_pol & bit_pol;

        elsif (r.spi.state = SPI_READ and r.QSPI = '0' and r.DSPI = '0') or (v.spi.state = SPI_ADDR) then
          v.ar := r.ar(r.ar'left-1 downto 0) & bit_pol;

        elsif (r.spimstate = USER_SPI and r.QSPI = '0' and r.DSPI = '0') then
          -- To keep backwards compatibility where a write to the TX register was used for both reading and writing
          -- to memory while in ESPI USER mode, r.spii(1).miso is shifted into the ar register here.
          v.ar := r.ar(r.ar'left-1 downto 0) & r.spii(1).miso;
        end if;
        
        -- Receive data from the memory and shift it into the ar register
        if v.spi.state = SPI_DATA or ((r.spimstate = USER_SPI) and r.spio.mosioen = INPUT) then
          case getOutputMode(r) is
            when 0 =>
              v.ar := r.ar(r.ar'left-1 downto 0) & r.spii(1).miso;
            when 1 =>
              v.ar := r.ar(r.ar'left-2 downto 0) & r.spii(1).miso & r.spii(1).mosi;
            when others =>
              v.ar := r.ar(r.ar'left-4 downto 0) & r.spii(1).io3 & r.spii(1).io2 & r.spii(1).miso & r.spii(1).mosi;
          end case;
        end if;

      end if;
    end if;
    
    if change = '1' and r.spi.state /= SPI_CSWAIT then

      -- Output data to the memory by shifting an appropriate number of bits in the sreg register
      if v.spio.misooen = INPUT  then
        -- If miso is in INPUT mode we are always to shift 1 bit as output
        v.spio.mosi := v.sreg(7);
        v.sreg(7 downto 0) := v.sreg(6 downto 0) & '1';
      elsif (v.spimstate = USER_SPI  and r.QSPI = '1') or
            (v.spimstate /= USER_SPI and getInputMode(r) = 2) then
        v.spio.mosi := v.sreg(4);
        v.spio.miso := v.sreg(5);
        v.spio.io2  := v.sreg(6);
        v.spio.io3  := v.sreg(7);
        v.sreg(7 downto 0) := v.sreg(3 downto 0) & "1111";
      else 
        -- Default to dual mode if neither single or quad mode
        v.spio.mosi := v.sreg(6);
        v.spio.miso := v.sreg(7);
        v.sreg(7 downto 0) := v.sreg(5 downto 0) & "11";
      end if;
      
    end if;
    
    -- Select and drive CSN using Chip Select Select signal
    case ds is
      when "00" => 
        v.spio.csn  := v.csn;
        v.spio.csn1 := '1';
        v.spio.csn2 := '1';
        v.spio.csn3 := '1';
      when "01" => 
        v.spio.csn  := '1';
        v.spio.csn1 := v.csn;
        v.spio.csn2 := '1';
        v.spio.csn3 := '1';
      when "10" => 
        v.spio.csn  := '1';
        v.spio.csn1 := '1';
        v.spio.csn2 := v.csn;
        v.spio.csn3 := '1';
      when others => 
        v.spio.csn  := '1';
        v.spio.csn1 := '1';
        v.spio.csn2 := '1';
        v.spio.csn3 := v.csn;
    end case;
    
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
      v.seq              := '0';
      v.stop             := '0';
      v.hold             := '1';
      v.unsplit          := '0';
      v.insplit          := '0';
      v.spi              := spiflash_none;
      --
      v.hready           := '1';
      v.hwrite           := '0';
      v.hsel             := '0';
      v.hmbsel           := (others => '0');
      v.ahbcancel        := '0';
      v.hwdata           := (others => '0');
      v.haddr            := (others => '0');
      --
      v.spio.sck         := '0';
      v.spio.mosi        := '1';
      v.spio.miso        := '1';
      v.spio.io2         := '1';
      v.spio.io3         := '1';
      v.spio.mosioen     := OUTPUT;
      v.spio.misooen     := INPUT;
      v.spio.iooen       := OUTPUT;
      v.spio.csn         := '1';
      v.spio.csn1        := '1';
      v.spio.csn2        := '1';
      v.spio.csn3        := '1';
      v.dsconf           := (others => '0');
      v.csn              := '1';
      v.ds               := (others => '0');
--       v.spio.errorn      := '1';
      --
      v.readcmd          := cslv(readcmd,8);
      v.writecmd         := cslv(writecmd,8);
      v.dualoutput       := to_ulogic(dualoutput);
      v.quadoutput       := to_ulogic(quadoutput);
      v.dualinput        := to_ulogic(dualinput);
      v.quadinput        := to_ulogic(quadinput);
      v.dummybyte        := to_ulogic(dummybyte);
      v.dummycycles      := cslv(dummycycles,4);
      v.DSPI             := to_ulogic(DSPI);
      v.QSPI             := to_ulogic(QSPI);
      case extaddr is
        when 0      => v.extaddr := '0';
        when 1      => v.extaddr := '1';
        when others => v.extaddr := spii.rstaddrm;
      end case;
      v.xip_byte         := to_ulogic(xip_byte);
      v.allow_writes     := to_ulogic(allow_writes);
      --
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
        hrdata(31 + 32*i downto 32*i) := r.rrdata;
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
  

end rtl;
