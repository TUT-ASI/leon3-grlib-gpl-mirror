------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2026, Frontgrade Gaisler
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
-- Entity:      imsic_int_files
-- File:        imsic_int_files.vhd
-- Author:      Francisco Bas, Frontgrade Gaisler AB
-- Description: Interrupt files from Incoming MSI Controller (IMSIC)
--
--              The IMSIC is divided into two distinct parts. On one side, an AHB
--              slave is implemented to receive MSIs (Message Signaled Interrupts)
--              through the bus. The AHB slave includes an interface to each CPU,
--              which is used to communicate interrupts transmitted through the bus.
--              
--              This file implements the IMSIC interrupt files instantiated in
--              each CPU. Its purpose is to receive interrupts from the IMSIC AHB
--              slave and forward interrupts to the CPU when they are enabled and
--              pending. Additionally, it handles reads and writes to the Interrupt
--              File Registers.
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.conv_integer;
use grlib.stdlib.conv_std_logic_vector;
use grlib.stdlib.log2x;

library gaisler;
use gaisler.noelvint.imsic_in_type;   
use gaisler.noelvint.imsic_out_type;   
use gaisler.noelv.imsic_irq_type;   
use gaisler.noelv.imsic_irq_none;   
use gaisler.noelv.nv_irq_in_type;   
use gaisler.noelv.XLEN;


entity imsic_int_files is
  generic (
    GEILEN       : integer                   := 0;   -- System virtual guest external interrupt number 
    S_EN         : integer range 0 to 1      := 0;   -- Set to 1 if supervisor mode is implemented
    H_EN         : integer range 0 to 1      := 0;   -- Set to 1 if hipervisor extension is implemented
    plic         : integer range 0 to 1      := 0;   -- Set to 1 if there is a PLIC/APLIC in the system
    -- The external interrupt identities in a interrupt file must be a multiple of 64 -1: from 63 to 2047 
    -- Each interrupt file can have a different number of external interrupt identities
    mnidentities : integer range 63 to 2047  := 63; 
    snidentities : integer range 63 to 2047  := 63; 
    gnidentities : integer range 63 to 2047  := 63;
    scantest     : integer                   := 0
    );
  port (
    rst        : in  std_ulogic;
    clk        : in  std_ulogic;
    irqi       : in  imsic_irq_type;
    acko       : out std_ulogic;
    plic_meip  : in  std_ulogic;
    plic_seip  : in  std_ulogic;
    imsici     : in  imsic_in_type;
    imsico     : out imsic_out_type;
    eip        : out nv_irq_in_type;
    testen     : in  std_ulogic;
    testrst    : in  std_ulogic
    );
end;


architecture rtl of imsic_int_files is
  constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  constant nsyncreg : integer := 2; -- Number of retisters used to synchronize data_rdy

  -- Since each interrupt file could have different number of interrupt identities we calculate
  -- the number of bits to store one interrupt identitiy for each mode
  constant mintidbits : integer := log2x(mnidentities);
  constant sintidbits : integer := log2x(snidentities);
  constant gintidbits : integer := log2x(gnidentities);

  type vs_vector is array (natural range <>) of std_logic_vector(XLEN-1 downto 0);
  type guestIntFile_in_type is record
    vstopei_w : std_logic_vector(GEILEN downto 1);    -- Virtual Supervisor top external interrupt write
    vsiselect : vs_vector(GEILEN downto 1);           -- Virtual Supervisor indirect register select value
    vsireg    : vs_vector(GEILEN downto 1);           -- Virtual Supervisor indirect register alias value
    vsireg_w  : std_logic_vector(GEILEN downto 1);    -- Virtual Supervisor indirect register alias write
  end record;

  type guestIntFile_out_type is record
    vstopei  : vs_vector(GEILEN downto 1);          -- Virtual top external interrupt register value
    vsireg   : vs_vector(GEILEN downto 1);          -- Virtual indirect register alias value
  end record;
  type guestIntFile_in_vector is array (natural range <>) of guestIntFile_in_type; 
  type guestIntFile_out_vector is array (natural range <>) of guestIntFile_out_type; 

  type reg_type is record
    -- Signals to propagate AHB writes to each IMSIC interrupt file
    mahbw      : std_ulogic;
    sahbw      : std_ulogic;
    gahbw      : std_logic_vector(GEILEN downto 1);
    seteipnum  : std_logic_vector(31 downto 0);
    -- Register to handle CDC
    irqi       : imsic_irq_type;
  end record;


  constant RES_T : reg_type := (
    mahbw       => '0',
    sahbw       => '0',
    gahbw       => (others => '0'),
    seteipnum   => (others => '0'),
    irqi        => imsic_irq_none
    );



  signal guest_in  : guestIntFile_in_type;
  signal guest_out : guestIntFile_out_type;
  signal r, rin    : reg_type;
  signal arst      : std_ulogic;

  -- Generic interrupt file
  component interrupt_file 
    generic (
      sources     : integer range 0 to 2047   := 2047; -- It must be a multiple of 64 -1: from 63 to 2047 
      plic        : integer range 0 to 1      := 1;    -- Set to 1 if there is a PLIC/APLIC in the system
      scantest    : integer                   := 0
      );
    port (
      rst         : in  std_ulogic;
      clk         : in  std_ulogic;
      -- AHB interface
      ahbw        : in  std_ulogic;
      seteipnum   : in  std_logic_vector(31 downto 0);
      -- Interface with CSRs
      ireg_w      : in  std_ulogic;
      iselect     : in  std_logic_vector(XLEN-1 downto 0);
      iregi       : in  std_logic_vector(XLEN-1 downto 0);
      irego       : out std_logic_vector(XLEN-1 downto 0);
      topei_w     : in  std_ulogic;
      topei       : out std_logic_vector(XLEN-1 downto 0);
      plic_eip    : in  std_ulogic;
      eipo        : out std_ulogic;
      testen      : in  std_ulogic;
      testrst     : in  std_ulogic
      );
  end component;

begin
  arst        <= testrst when (ASYNC_RESET and scantest/=0 and testen/='0') else
                 rst when ASYNC_RESET else '1';

  -- Machine Interrupt File
  machine_file : interrupt_file
  generic map(
    sources     => mnidentities,
    plic        => plic,
    scantest    => scantest
    )
  port map(
    rst         => rst,
    clk         => clk,
    -- AHB writes propagation
    ahbw        => r.mahbw,
    seteipnum   => r.seteipnum,
    -- Indirectly accessed interrupt-file registers interface
    ireg_w      => imsici.mireg_w,
    iselect     => imsici.miselect,
    iregi       => imsici.mireg,
    irego       => imsico.mireg,
    topei_w     => imsici.mtopei_w, 
    topei       => imsico.mtopei,
    plic_eip    => plic_meip,
    eipo        => eip.meip,
    testen      => testen,
    testrst     => testrst
    );

  -- Supervisor Interrupt File
  supervisor_int_files: if S_EN = 1 generate
    supervisor_file : interrupt_file
    generic map(
      sources     => snidentities,
      plic        => plic,
      scantest    => scantest
      )
    port map(
      rst         => rst,
      clk         => clk,
      -- AHB writes propagation
      ahbw        => r.sahbw,
      seteipnum   => r.seteipnum,
      -- Indirectly accessed interrupt-file registers interface
      ireg_w      => imsici.sireg_w,
      iselect     => imsici.siselect,
      iregi       => imsici.sireg,
      irego       => imsico.sireg,
      topei_w     => imsici.stopei_w, 
      topei       => imsico.stopei,
      plic_eip    => plic_seip,
      eipo        => eip.seip,
      testen      => testen,
      testrst     => testrst
      );
  end generate supervisor_int_files;



  -- Guest Interrupt Files
  -- Only the guest interrupt file pointed by vgein is used
  vgein_mux : for guest in 1 to GEILEN generate
    -- INPUTS
    guest_in.vsireg_w(guest)  <= imsici.vsireg_w when unsigned(imsici.vgein) = guest else
                                      '0'; 
    guest_in.vsiselect(guest) <= imsici.vsiselect when unsigned(imsici.vgein) = guest else
                                      (others => '0'); 
    guest_in.vsireg(guest)    <= imsici.vsireg when unsigned(imsici.vgein) = guest else
                                      (others => '0'); 
    guest_in.vstopei_w(guest) <= imsici.vstopei_w when unsigned(imsici.vgein) = guest else
                                      '0'; 
  end generate vgein_mux;
  -- OUTPUTS
  imsico.vsireg  <= guest_out.vsireg(conv_integer(imsici.vgein)) when 
                              unsigned(imsici.vgein) /= 0 and unsigned(imsici.vgein) <= GEILEN else
                         (others => '0'); 
  imsico.vstopei <= guest_out.vstopei(conv_integer(imsici.vgein)) when 
                              unsigned(imsici.vgein) /= 0 and unsigned(imsici.vgein) <= GEILEN else
                         (others => '0'); 

  guest_int_files: if H_EN = 1 generate
    guest_int_files_g_gen : for i in 1 to GEILEN generate
      guest_file : interrupt_file
      generic map(
        sources     => gnidentities,
        plic        => 0, -- Guest interrupt files do not support eidelivery=0x40000000
        scantest    => scantest
      )
      port map(
        rst         => rst,
        clk         => clk,
        -- AHB writes propagation
        ahbw        => r.gahbw(i),
        seteipnum   => r.seteipnum,
        -- Indirectly accessed interrupt-file registers interface
        ireg_w      => guest_in.vsireg_w(i),
        iselect     => guest_in.vsiselect(i),
        iregi       => guest_in.vsireg(i),
        irego       => guest_out.vsireg(i),
        topei_w     => guest_in.vstopei_w(i), 
        topei       => guest_out.vstopei(i),
        plic_eip    => '0',
        eipo        => eip.hgeip(i),
        testen      => testen,
        testrst     => testrst
        );
    end generate guest_int_files_g_gen;
  end generate guest_int_files;

  -- These are added elsewhere
  eip.mtip    <= '0';
  eip.msip    <= '0';
  eip.ssip    <= '0';
  eip.stime   <= (others => '0');
  -- AIA
  eip.imsic      <= imsic_irq_none;
  eip.aplic_meip <= '0';
  eip.aplic_seip <= '0';
  -- RNMI
  eip.nmirq   <= (others => '0');

  comb : process (r, irqi) is
    variable v             : reg_type;
    variable data_rdy_edge : std_ulogic;
  begin

    ----------------------------------------------------
    -- Interface with IMSIC AHB Slave
    ----------------------------------------------------

    v := r;

    v.mahbw := '0';
    v.sahbw := '0';
    for i in 1 to GEILEN loop
      v.gahbw(i) := '0';
    end loop;
    acko <= '0';

    v.irqi        := irqi;  -- TODO: is it needed to register all the imsic inputs
    data_rdy_edge := irqi.data_rdy and not r.irqi.data_rdy;


    -- When there is a positive flank in data_rdy signal is safe to read data
    -- coming from IMSIC AHB slave and write the Interrupt File
    if data_rdy_edge = '1' then
      if irqi.supervisor = '0' then
        v.seteipnum(mintidbits-1 downto 0) := irqi.int_id(mintidbits-1 downto 0);
        v.mahbw := '1';
      elsif unsigned(irqi.guest) = 0 then
        v.seteipnum(sintidbits-1 downto 0) := irqi.int_id(sintidbits-1 downto 0);
        v.sahbw := '1';
      else
        v.gahbw(conv_integer(irqi.guest)) := '1';
        v.seteipnum(gintidbits-1 downto 0) := irqi.int_id(gintidbits-1 downto 0);
      end if;
      -- Once information has been read set ack signal
      acko <= '1';
    end if;


    rin <= v;

  end process;


  syncrregs : if not ASYNC_RESET generate
    regs : process(clk)
    begin
      if rising_edge(clk) then
        r <= rin;
        if rst = '0' then
          r <= RES_T;
        end if;
      end if;
    end process;
  end generate;

  asyncrregs : if ASYNC_RESET generate
    regs : process(clk, arst)
    begin
      if arst = '0' then
        r <= RES_T;
      elsif rising_edge(clk) then
        r <= rin;
      end if;
    end process;
  end generate;

end rtl;
