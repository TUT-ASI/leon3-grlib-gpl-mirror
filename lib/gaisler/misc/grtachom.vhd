------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
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
--------------------------------------------------------------------------------
-- Entity:      grtachom
-- File:	grtachom.vhd
-- Description: Top level entity for the GRTACHOM
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.std_logic_unsigned.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;


entity grtachom is
  generic (
    tech           : integer        := inferred;
    pindex         : integer        := 0;
    paddr          : integer        := 0;
    pmask          : integer        := 16#FFF#;
    pirq           : integer        := 0); --Not used
  port (
    clk            : in  std_ulogic;
    rstn           : in  std_ulogic;
    -- APB interface
    apbi           : in  apb_slv_in_type;
    apbo           : out apb_slv_out_type;
    -- Tacho inputs
    tacho           : in  std_logic_vector(3 downto 0);
    tacho_sign      : in  std_logic_vector(3 downto 0)
    );
end entity grtachom;

architecture rtl of grtachom is

  ----------------------------------------------------------------------------
  -- Constant declaration
  -----------------------------------------------------------------------------

  ---- Reset configuration ----
  
  constant ASYNC_RST  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  ---- APB address mapping ----

  -- General registers
  constant CTRL_REG         : std_logic_vector(7 downto 2) := "000000"; -- 0x000
  constant STAT_REG         : std_logic_vector(7 downto 2) := "000001"; -- 0x004
  constant SCALER_REG       : std_logic_vector(7 downto 2) := "000010"; -- 0x008
  -- Static Value registers
  constant TACHO_01_REG     : std_logic_vector(7 downto 2) := "000100"; -- 0x010
  constant TACHO_23_REG     : std_logic_vector(7 downto 2) := "000101"; -- 0x014
  -- Running counters registers
  constant RTACHO_01_REG    : std_logic_vector(7 downto 2) := "001000"; -- 0x020
  constant RTACHO_23_REG    : std_logic_vector(7 downto 2) := "001001"; -- 0x024


  ---- Plug and Play Information (APB interface)

  constant REVISION  : integer := 0;
  constant pconfig   : apb_config_type := (
    0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_GRTACHOM, 0, REVISION, 0),
    1 => apb_iobar(paddr, pmask));


  ---- Registers type definitions --------------------------------

  type ctrl_reg_type is record   
    en_tacho          : std_logic_vector(3 downto 0);
  end record;

  constant CTRL_REG_RST : ctrl_reg_type := (
     en_tacho          => (others => '0')
    );

  type sts_reg_type is record
    reg_lock       : std_logic_vector(1 downto 0);
  end record;

  constant STS_REG_RST : sts_reg_type := (
    reg_lock             => (others =>'0')
    );

  type tacho_reg_type is record
    count       : std_logic_vector (14 downto 0);
    sign        : std_ulogic;
  end record;

  constant TACHO_REG_RST : tacho_reg_type := (
    count       => (others =>'0'),
    sign  =>'0'
  );

  type tacho_4regs_type is array (3 downto 0) of tacho_reg_type;

  constant TACHO_4REGS_RST :  tacho_4regs_type := (
    TACHO_REG_RST,TACHO_REG_RST,TACHO_REG_RST,TACHO_REG_RST
    );

  type counters_32b is array (3 downto 0) of std_logic_vector(31 downto 0);

  constant COUNTERS32B_REG_RST : counters_32b := (
    (others=>'0'),(others=>'0'),(others=>'0'),(others=>'0')
    );
    
  type grtachom_reg_type is record
    -- APB acces registers
    regrst         : std_ulogic;
    ctrl           : ctrl_reg_type;
    status         : sts_reg_type;
    scaler         : std_logic_vector (31 downto 0);
    tacho_reg      : tacho_4regs_type;
    run_tacho_reg  : tacho_4regs_type;
    
    -- Core registers
    counter_1s     : counters_32b;
    tacho_sync_reg : std_logic_vector (3 downto 0);
    reset_tacho    : std_logic_vector (3 downto 0); 

    
  end record;
  
 constant GRTACHOM_REG_RST : grtachom_reg_type := (
    regrst            => '1',
    ctrl              => CTRL_REG_RST,
    status            => STS_REG_RST,
    scaler            => (others => '0'),
    tacho_reg         => TACHO_4REGS_RST,
    run_tacho_reg     => TACHO_4REGS_RST,

    counter_1s        => COUNTERS32B_REG_RST,
    tacho_sync_reg    => (others => '0'),
    reset_tacho       => (others => '0')
        
    );

  -----------------------------------------------------------------------------
  -- Signal declaration
  -----------------------------------------------------------------------------

  -- TACHO synchronization and selection
  signal tacho_sync         : std_logic_vector(3 downto 0);
  signal tacho_sign_sync    : std_logic_vector(3 downto 0);
  
  -- Register signals
  signal r, rin              : grtachom_reg_type;
  
begin

  ---- APB interface ----
  apbo.pindex   <= pindex;
  apbo.pconfig  <= pconfig;
  
  -- Input synchronization with double flip-flop
  gen_syncregs: for i in 0 to 3 generate 
    syncreg_tach: syncreg generic map (tech, 2) port map (clk, tacho(i),tacho_sync(i));
    syncreg_sign: syncreg generic map (tech, 2) port map (clk, tacho_sign(i),tacho_sign_sync(i));
  end generate;

  comb : process (r, apbi, tacho_sync,tacho_sign_sync)

    variable v               : grtachom_reg_type;
    variable prdata          : std_logic_vector(31 downto 0);
    variable paddr7_2        : std_logic_vector(7 downto 2);
 
  begin

    -----------------------------------------------------------------------------
    -- Variable initialization
    -----------------------------------------------------------------------------
    
    v := r;
    prdata    := (others => '0');
    paddr7_2  := apbi.paddr(7 downto 2);

    -- Register the value of the tacho inputs
    v.tacho_sync_reg := tacho_sync;
  
    ---- Read access ----
    if (apbi.psel(pindex) and apbi.penable and (not apbi.pwrite)) = '1' then
      case paddr7_2 is

        when CTRL_REG => 
          prdata(3 downto 0) := r.ctrl.en_tacho;
        when STAT_REG =>
          prdata(0)          := r.status.reg_lock(0);
          prdata(4)          := r.status.reg_lock(1);

        when SCALER_REG =>
          prdata(31 downto 0)  := r.scaler;
          
        when TACHO_01_REG =>        
          prdata(31)           := r.tacho_reg(1).sign;
          prdata(30 downto 16) := r.tacho_reg(1).count;
          prdata(15)           := r.tacho_reg(0).sign;
          prdata(14 downto 0)  := r.tacho_reg(0).count;
          -- Lock the register value until both the registers have been read.
          v.status.reg_lock(0)        := '1';
                
        when TACHO_23_REG =>
          prdata (31)          := r.tacho_reg(3).sign;
          prdata(30 downto 16) := r.tacho_reg(3).count;
          prdata(15)           := r.tacho_reg(2).sign;
          prdata(14 downto 0)  := r.tacho_reg(2).count;
          -- Lock the register value until both the registers have been read.
          v.status.reg_lock(1)        := '1';
          
        when RTACHO_01_REG =>
          prdata (31)          := r.run_tacho_reg(1).sign;
          prdata(30 downto 16) := r.run_tacho_reg(1).count;
          prdata(15)           := r.run_tacho_reg(0).sign;
          prdata(14 downto 0)  := r.run_tacho_reg(0).count;
          
        when RTACHO_23_REG =>
          prdata (31)          := r.run_tacho_reg(3).sign;
          prdata(30 downto 16) := r.run_tacho_reg(3).count;
          prdata(15)           := r.run_tacho_reg(2).sign;
          prdata(14 downto 0)  := r.run_tacho_reg(2).count;

        when others =>
          null;

      end case;
    end if;

    ---- Write access ----
    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
      case paddr7_2 is

        when CTRL_REG =>
          v.regrst           := not apbi.pwdata(31); -- Active-low reset
          v.ctrl.en_tacho    := apbi.pwdata(3 downto 0);

        when SCALER_REG =>
          v.scaler           := apbi.pwdata (31 downto 0);
      
        -- The other registers are read only
        when others =>
          null;

      end case;
    end if;
    
    -- Clear lock signals if both the TACHO registers have been read
    if ( v.status.reg_lock = "11") then
      v.status.reg_lock := (others=>'0');
    end if;


    gentachos: for i in 0 to 3 loop
    
      if(r.ctrl.en_tacho(i) = '0') then
        --Reset all the registers if the channel is not enabled
        v.run_tacho_reg(i)  := TACHO_REG_RST;
        v.tacho_reg(i)      := TACHO_REG_RST;
        v.counter_1s(i)     := (others => '0');
      else
        
        -- Upload the tacho sign with the current value
        v.run_tacho_reg(i).sign  := tacho_sign_sync(i);

        -- Reset the tacho if the tacho sign changes. The reset takes action
        -- only if the sign variation takes place after the first tick in the scaler.
        if( r.run_tacho_reg(i).sign /=  tacho_sign_sync(i)) then
          if(r.counter_1s(i) /= X"00000000" ) then
            v.reset_tacho(i)    := '1';
          end if;
        else
          v.reset_tacho(i)    := '0';
        end if;
                    
        -- Reset the tacho if there is a variation in the scaler value
        if (v.scaler /= r.scaler) then
          v.reset_tacho(i)    := '1';
        end if;

        if (r.reset_tacho(i) = '1') then
          v.run_tacho_reg(i).count := (others => '0');
          v.counter_1s(i)          := (others => '0');
        else
          -----------------------Scaler -------------------------------
          if(r.counter_1s(i) = r.scaler) then
            v.reset_tacho(i)   := '1';
            if (v.status.reg_lock = "00") then
              --If the registers are not locked then pass the data from the
              --running registers to the static ones
              v.tacho_reg(i).count := v.run_tacho_reg(i).count;
              v.tacho_reg(i).sign  := v.run_tacho_reg(i).sign;
            end if;
          else
            v.counter_1s(i) := r.counter_1s(i) +1;
          end if;
          
          -----------Tacho counter-----------------------------------------------
          -- Update the counter only if detecting a positive edge
          if ( r.tacho_sync_reg(i) /= tacho_sync(i) and tacho_sync(i) = '1') then
            v.run_tacho_reg(i).count := r.run_tacho_reg(i).count+1;
          end if;
          
        end if;
        
      end if;

    end loop gentachos;
    
    -----------------------------------------------------------------------------
    -- Register signals update
    -----------------------------------------------------------------------------

    rin         <= v;
    apbo.prdata <= prdata;

    -- No interrupts
    apbo.pirq             <= (others => '0');   

  end process comb;

  seq : process (clk, rstn)
  begin
    if rstn = '0' and ASYNC_RST then
      -- Asynchronous reset scheme
      r <= GRTACHOM_REG_RST;
    elsif rising_edge(clk) then
      if rstn = '0' or r.regrst = '0' then
        -- Synchronous reset scheme
        r <= GRTACHOM_REG_RST;
      else
        r <= rin;
      end if;
    end if;
  end process seq;


end architecture rtl;
