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
-- Entity:      rv_intctrl_abh
-- File:        rv_intctrl_ahb.vhd
-- Author:      Francisco Bas, Frontgrade Gaisler
-- Description: RISC-V Interrupt Controllers. Any combination of the following
--              RISC-V interrupt controllers may be present: ACLINT, IMSIC,
--              APLIC and PLIC. If IMSIC or APLIC are enabled together with
--              the PLIC, external interrupts from the AIA interrupt controllers
--              and the PLIC are ORed. All interrupt controllers are mapped to
--              the four memory bars of the slave. The first user-defined bar
--              contains 4 bits that can be read to discover which interrupt
--              controllers are present in the system.
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.zero32;
use grlib.stdlib."+";
use grlib.stdlib."-";
use grlib.stdlib.log2x;
use grlib.stdlib.conv_std_logic;
use grlib.stdlib.conv_std_logic_vector;

library gaisler;
use gaisler.noelv.all;
use gaisler.plic.all;
use gaisler.aplic.all;
use gaisler.l5nv_shared.l5_tsc_ctrl_type;
use gaisler.l5nv_shared.l5_tsc_ctrl_none;

entity rv_intctrl_ahb is
  generic (
    -- AHB
    hindex      : integer range 0 to NAHBSLV-1  := 0;
    haddr       : integer range 0 to 16#FFF#    := 0;
    hmindex     : integer range 0 to NAHBMST-1  := 0;
    scantest    : integer                       := 0;
    -- GENERAL
    ncpu        : integer range 0 to 32         := 4;  -- So far limited to 32 by APLIC
    S_EN        : integer range 0 to 1          := 0;  -- Set to 1 if supervisor mode is implemented
    H_EN        : integer range 0 to 1          := 0;  -- Set to 1 if hipervisor extension is implemented
    GEILEN      : integer                       := 0;  -- System virtual guest external interrupt number
    nsources    : integer range 0 to RISCV_SOURCES := NAHBIRQ;

    -- ACLINT
    enable_aclint : integer                     := 0;
    aclint_haddr: integer range 0 to 16#FFF#    := 0;  -- If not set ACLINT will be arranged contigous to PLIC
    aclint_ts   : integer range 0 to 1          := 0;  -- Chose between a tsc generator or a rtc for time source
    hirq1       : integer range 0 to NAHBSLV-1  := 0;
    hirq2       : integer range 0 to NAHBSLV-1  := 0;
    mswi        : integer range 0 to 1          := 1;  -- Enables MSWI ACLINT's device (machine software interrupts)
    mtimer      : integer range 0 to 1          := 1;  -- Enables MTIMER ACLINT's device (machine timer interrupts)
    mtimebits   : integer range 33 to 64        := 63; -- mtime number of bits
    asyncset    : integer range 0 to 1;
    sswi        : integer range 0 to 1          := 1;  -- Enables SSWI ACLINT's device (supervisor software interrupts)
    watchdog    : integer range 0 to 1          := 1;  -- Enables watchdog
    wdtickbit   : integer range 0 to 63         := 4;  -- MTIME bit used for the watchdog tick
    -- IMSIC
    enable_imsic : integer                      := 0;
    imsic_haddr : integer range 0 to 16#FFF#    := 0;  -- If not set IMSIC will be arranged contigous to ACLINT
    groups      : integer                       := 0;  -- Number of core groups (set to 0 if cores are not grouped)
    neiid       : integer range 0 to 2047       := 63; -- external interrupt identities must be a multiple of 64 -1
    -- APLIC
    enable_aplic        : integer                        := 0;
    aplic_haddr         : integer range 0 to 16#FFF#     := 0;           -- If not set APLIC will be arranged contigous to IMSIC
    branches            : integer range 0 to 10          := 1;           -- Number of branches in the domain hirarchy
    doms_per_branch     : integer range 0 to MAX_DOMAINS := 3;           -- Number of domains in each branch
    endianness          : integer range 0 to 2           := 0;           -- 0 => little; 1 => big; 2 => bi
    mmsiaddrcfg_fixed   : integer range 0 to 1           := 1;           -- If set to 1, registers mmsiaddrcfg/mmsiaddrcfgh/smsiaddrcfgh/smsiaddrcfgh are fixed
                                                                         -- and cannot be accessed. Their values are set through generics mLHXS/sLHXS/HHXS/LHXW/HHXW
    direct_delivery     : integer range 0 to 1           := 0;           -- If set to 0 direct delivery mode is not implemented 
    IPRIOLEN            : integer range 1 to 8           := 8;           -- IPRIO has values between 1 and 2^IPRIOLEN (used when there is no IMSIC and the APLIC acts as interrupt controller)
    leaf_domains        : std_logic_vector(MAX_DOMAINS-1 downto 0) := (others => '0'); -- Configures the leaf domains
    preset_active_harts : preset_active_harts_type;                      -- Configures for each domain which cores are elegibles (through target registers) to forward the interrupts (Reset value)
    -- PLIC
    enable_plic : integer                       := 0;
    plic_haddr  : integer range 0 to 16#FFF#    := 0;  -- If not set ACLINT will be instanciated in haddr
    priorities  : integer range 0 to 128        := 8;
    pendingbuff : integer range 0 to 128        := 1;
    irqtype     : integer range 0 to 2          := 2;
    irqtyperst  : integer range 0 to 2          := 1;
    thrshld     : integer range 0 to 1          := 1
    );
  port (
    rstn        : in  std_ulogic;
    clk         : in  std_ulogic;
    -- AHB
    ahbi        : in  ahb_slv_in_type;
    ahbo        : out ahb_slv_out_type;
    ahbmi       : in  ahb_mst_in_type                        := ahbm_in_none;
    ahbmo       : out ahb_mst_out_type;
    -- ACLINT
    timer       : in  std_logic_vector(mtimebits-1 downto 0) := (others => '0');
    rtc         : in  std_ulogic                             := '0';
    halt        : in  std_ulogic                             := '0';
    ack         : in  std_ulogic                             := '0';
    ctrl        : out l5_tsc_ctrl_type;
    -- IMSIC
    irq_ack     : in  std_logic_vector(0 to ncpu-1)          := (others => '1');
    -- External RNMI
    rnmi_irq    : in  std_logic_vector(ncpu-1 downto 0)      := (others => '0');
    -- Interrupts
    irqi        : out nv_irq_in_vector(0 to ncpu-1)
    );
end;

architecture rtl of rv_intctrl_ahb is
  constant RESET_ALL    : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;
  constant ASYNC_RESET  : boolean := GRLIB_CONFIG_ARRAY(grlib_async_reset_enable) = 1;

  constant zero32 : std_logic_vector(31 downto 0) := (others => '0');

  constant ACLINT_VERSION : integer := 0;
  constant IMSIC_VERSION  : integer := 0;
  constant APLIC_VERSION  : integer := 0;
  constant PLIC_VERSION   : integer := 0;

  -- IMSIC CONFIGURATION -----------------------------------------------------------
  -- Functions
  function set_G_EN(value : integer) return integer is
  begin
    if value = 0 then
      return 0;
    else
      return 1;
    end if;
  end function;

  function calc_CpG(ncpu : integer; groups : integer; G_EN : integer) return integer is
    variable CoresPerGroup : integer;
  begin
    if G_EN = 0 then
      CoresPerGroup := ncpu;
    else
      CoresPerGroup := ncpu/groups;
    end if;
    return CoresPerGroup;
  end function;

  -- Constants
  constant nintid  : nidentities_vector(0 to ncpu - 1)          := (others => neiid);
  constant gnintid : nidentities_vector(0 to ncpu * GEILEN - 1) := (others => neiid);

  constant G_EN           : integer range 0 to 1 := set_G_EN(groups); -- If groups is different to 0, then G_EN is 1
  constant CoresPerGroup  : integer := calc_CpG(ncpu, groups, G_EN);
  constant ncpubits       : integer := log2x(CoresPerGroup);       -- If cores are not grouped CoresPerGroup = ncpu
  constant vcpubits       : integer := log2x(GEILEN+1);               -- One is added because the group also cotains the supervisor hart
  constant groupbits      : integer := log2x(groups);
  constant total_bits     : integer := S_EN+G_EN*groupbits+H_EN*vcpubits+ncpubits+12;


  -- APLIC CONFIGURATION ----------------------------------------------------------

  -- Functions
  function calc_sbase(
    base      : std_logic_vector(31 downto 0);
    ncpu      : integer;
    groups    : integer;
    H_EN      : integer range 0 to 1;
    nvcpubits : integer)                         -- guest hart
    return std_logic_vector is
      variable addr      : std_logic_vector(31 downto 0);
      variable ncpubits  : integer;
      variable groupbits : integer;
      variable bitnumber : integer;
  begin
    if groups = 0 then
      ncpubits  := log2x(ncpu);
      bitnumber := ncpubits + nvcpubits * H_EN + 12;
    else
      ncpubits  := log2x(ncpu / groups);
      groupbits := log2x(groups);
      bitnumber := ncpubits + nvcpubits * H_EN + groupbits + 12;
    end if;
    addr := base;
    addr(bitnumber) := '1';
    return addr;
  end function;

  function set_intcap_csr(aclint_en   : integer;
                          plic_en     : integer;
                          imsic_en    : integer;
                          aplic_en    : integer;
                          nsources    : integer;
                          geilen      : integer;
                          directdel   : integer;
                          ipriolen    : integer;
                          domsxbranch : integer;
                          branches    : integer;
                          neiid       : integer;
                          groups      : integer
                          ) return std_logic_vector is
    variable value : std_logic_vector(63 downto 0);
  begin
    value(63 downto 59) := (others => '0');
    value(58)           := conv_std_logic(directdel /= 0);
    value(57 downto 54) := conv_std_logic_vector(ipriolen, 4);
    value(53 downto 49) := conv_std_logic_vector(domsxbranch, 5);
    value(48 downto 40) := conv_std_logic_vector(branches, 9);
    value(39 downto 32) := conv_std_logic_vector(groups, 8);
    value(31 downto 21) := conv_std_logic_vector(neiid, 11);
    value(20 downto 15) := conv_std_logic_vector(geilen, 6);
    value(14 downto 4)  := conv_std_logic_vector(nsources, 11);
    value(3)            := conv_std_logic(aplic_en /= 0);
    value(2)            := conv_std_logic(imsic_en /= 0);
    value(1)            := conv_std_logic(plic_en /= 0);
    value(0)            := conv_std_logic(aclint_en /= 0);

    return value;
  end;

  constant interrupt_cap : std_logic_vector(63 downto 0) := set_intcap_csr(aclint_en   => enable_aclint,
                                                                           plic_en     => enable_plic,
                                                                           imsic_en    => enable_imsic,
                                                                           aplic_en    => enable_aplic,
                                                                           nsources    => nsources,
                                                                           geilen      => GEILEN,
                                                                           directdel   => direct_delivery,
                                                                           ipriolen    => ipriolen,
                                                                           domsxbranch => doms_per_branch,
                                                                           branches    => branches,
                                                                           neiid       => neiid,
                                                                           groups      => groups);


  -- General constants
  constant ndomains : integer  := branches*doms_per_branch+1;


  -- PLIC CONFIGURATION ------------------------------------------------------------
  constant context_per_core : integer := 4;
  constant plic_contexts    : integer := context_per_core * ncpu;

  function get_plic_mask(ncontexts : integer) return integer is
    --variable higher_addr   : integer;
    variable higher_addr   : std_logic_vector(31 downto 0);
    variable higher_addr_h : std_logic_vector(11 downto 0);
    variable mask          : std_logic_vector(11 downto 0) := (others => '0');
  begin
    higher_addr   := conv_std_logic_vector(16#200000# + 16#1000# * ncontexts, 32);
    higher_addr_h := higher_addr(31 downto 20);
    for i in 11 downto 0 loop
      if higher_addr_h(i) = '0' then
        mask(i) := '1';
      else
        return to_integer(unsigned(mask));
      end if;
    end loop;
  end function;


  -- AHB CONFIGURATION -------------------------------------------------------------

  constant aclint_hbar : integer := 0;
  constant imsic_hbar  : integer := 1;
  constant aplic_hbar  : integer := 2;
  constant plic_hbar   : integer := 3;

  -- set_haddr function calculates the address of each interrupt controller to meet the following description:
  -- Address space:
  -- Each slave can be assigned to a custom address setting its haddr generic
  -- If the haddr generic is unset, is set to 0 and the interrupt controller is enabled, the salve is
  -- arranged to the next valid empty address following the order below:

  --  BASE ADDRESS
  -----------------------------------------------------------------------------------------------------------------
  --  ACLINT (1MB)                                                                |                  |            |
  --  IMSIC  (Depends on the number of cores and virtual guests) (Usually 1 MB)   | => (usually 3MB) |            |
  --  APLIC  (Depends on the number of cores) (Usually 1 MB)                      |                  | => 64 MB   |
  ---------------------------------------------------------------------------------                  |            |
  --  (empty AHB space until 64 MB)                                                                  |            |
  ---------------------------------------------------------------------------------------------------|            |
  --  PLIC   (64 MB)                                                                                              |
  ----------------------------------------------------------------------------------------------------------------|
  -- ACLINT, IMSIC and APLIC are always arranged in the beginning of the memory map in the order
  -- shown above.
  -- PLIC needs to be aligned to 64 MB. Therefore if ACLINT, IMSIC or APLIC are present, PLIC will be
  -- arranged in the memory address RVINTCTRL_ADDR+64MB. If PLIC is the only interrupt controller, its
  -- memory base address will coincide with RVINTCTRL_ADDR.
  function set_haddr(enable_aclint : integer; aclint_haddr : integer; aclint_hmask : integer;
                     enable_imsic  : integer; imsic_haddr  : integer; imsic_hmask  : integer;
                     enable_aplic  : integer; aplic_haddr  : integer; aplic_hmask  : integer;
                     enable_plic   : integer; plic_haddr   : integer; plic_hmask   : integer;
                     base_haddr    : integer; intctrl_sel  : integer) return integer is
    variable haddr  : integer := 0;
    variable nhaddr : integer := base_haddr;
  begin
    if intctrl_sel >= 0 then
      if aclint_haddr /= 0 then
        haddr := aclint_haddr;
      elsif enable_aclint /= 0 then
        haddr  := base_haddr;
        nhaddr := haddr + (16#FFF#-aclint_hmask) + 1;
      end if;
    end if;
    if intctrl_sel > 0 then
      if imsic_haddr /= 0 then
        haddr := imsic_haddr;
      elsif enable_imsic /= 0 then
        haddr  := nhaddr;
        nhaddr := haddr + (16#FFF#-imsic_hmask) + 1;
        -- Make sure the address is properly aligned
        nhaddr := to_integer(to_unsigned(nhaddr, 12) and to_unsigned(imsic_hmask, 12));
      end if;
    end if;
    if intctrl_sel > 1 then
      if aplic_haddr /= 0 then
        haddr := aplic_haddr;
      elsif enable_aplic /= 0 then
        haddr  := nhaddr;
        nhaddr := haddr + (16#FFF#-aplic_hmask) + 1;
        -- Make sure the address is properly aligned
        nhaddr := to_integer(to_unsigned(nhaddr, 12) and to_unsigned(imsic_hmask, 12));
      end if;
    end if;
    if intctrl_sel > 2 then
      if plic_haddr /= 0 then
        haddr := plic_haddr;
      elsif enable_plic /= 0 then
        if nhaddr = base_haddr then
          haddr := base_haddr;
        else
          haddr := base_haddr + 64;
        end if;
      end if;
    end if;

    return haddr;

  end set_haddr;


  -- HCONFIG
  constant REVISION : integer := 0;

  constant aclint_hmask : integer := 16#FFF#;                          -- 1  MB
  constant imsic_hmask  : integer := bits2hmask(total_bits);           -- Usually 1 MB
  constant aplic_hmask  : integer := bits2hmask(15+log2x(ndomains+1)); -- Usually 1 MB
  constant plic_hmask   : integer := get_plic_mask(plic_contexts);     -- Usually 2-16 MB

  constant laclint_haddr : integer := set_haddr(enable_aclint, aclint_haddr, aclint_hmask,
                                                enable_imsic, imsic_haddr, imsic_hmask,
                                                enable_aplic, aplic_haddr, aplic_hmask,
                                                enable_plic, plic_haddr, plic_hmask,
                                                haddr, aclint_hbar);
  constant limsic_haddr : integer  := set_haddr(enable_aclint, aclint_haddr, aclint_hmask,
                                                enable_imsic, imsic_haddr, imsic_hmask,
                                                enable_aplic, aplic_haddr, aplic_hmask,
                                                enable_plic, plic_haddr, plic_hmask,
                                                haddr, imsic_hbar);
  constant laplic_haddr : integer  := set_haddr(enable_aclint, aclint_haddr, aclint_hmask,
                                                enable_imsic, imsic_haddr, imsic_hmask,
                                                enable_aplic, aplic_haddr, aplic_hmask,
                                                enable_plic, plic_haddr, plic_hmask,
                                                haddr, aplic_hbar);
  constant lplic_haddr : integer   := set_haddr(enable_aclint, aclint_haddr, aclint_hmask,
                                                enable_imsic, imsic_haddr, imsic_hmask,
                                                enable_aplic, aplic_haddr, aplic_hmask,
                                                enable_plic, plic_haddr, plic_hmask,
                                                haddr, plic_hbar);


  function set_hconfig(enable_aclint : integer; aclint_haddr : integer; aclint_hmask : integer;
                       enable_imsic : integer; imsic_haddr  : integer; imsic_hmask  : integer;
                       enable_aplic : integer; aplic_haddr  : integer; aplic_hmask  : integer;
                       enable_plic  : integer; plic_haddr   : integer; plic_hmask   : integer
                      ) return ahb_config_type is
    variable hconfig  : ahb_config_type := (others => (others => '0'));
    variable REVISION : integer := 0;
  begin
    hconfig(0) := ahb_device_reg ( VENDOR_GAISLER, GAISLER_RVINTCTRL, 0, REVISION, 0);
    -- The 4 LSB of this PnP bar is used to discover which interrupt controllers are implemented
    hconfig(1)(3 downto 0) := conv_std_logic(enable_plic /= 0) & conv_std_logic(enable_aplic /= 0) &
                              conv_std_logic(enable_imsic /= 0) & conv_std_logic(enable_aclint /= 0);
    -- The Versions of the interrupt controllers are encoded in bits 31-12
    hconfig(1)(31 downto 12) := conv_std_logic_vector(PLIC_VERSION, 5)  & conv_std_logic_vector(APLIC_VERSION, 5) &
                                conv_std_logic_vector(IMSIC_VERSION, 5) & conv_std_logic_vector(ACLINT_VERSION, 5);
    -- The rest of the bits are reserved
    hconfig(1)(11 downto 4)  := x"00";
    if enable_aclint /= 0 then
      hconfig(4) := ahb_membar(aclint_haddr, '0', '0', aclint_hmask);
    end if;
    if enable_imsic /= 0 then
      hconfig(5) := ahb_membar(imsic_haddr, '0', '0', imsic_hmask);
    end if;
    if enable_aplic /= 0 then
      hconfig(6) := ahb_membar(aplic_haddr, '0', '0', aplic_hmask);
    end if;
    if enable_plic /= 0 then
      hconfig(7) := ahb_membar(plic_haddr, '0', '0', plic_hmask);
    end if;
    return hconfig;
  end;

  constant hconfig : ahb_config_type := set_hconfig(enable_aclint, laclint_haddr, aclint_hmask,
                                                    enable_imsic , limsic_haddr , imsic_hmask ,
                                                    enable_aplic , laplic_haddr , aplic_hmask ,
                                                    enable_plic  , lplic_haddr  , plic_hmask);


  -- MSI Delivery Mode constants
  constant IMSIC_ADDR : std_logic_vector(31 downto 0)  := conv_std_logic_vector(limsic_haddr, 12) & x"00000";
  constant mbase_PPN  : std_logic_vector(31 downto 0)  := x"000" & IMSIC_ADDR(31 downto 12);  -- base_ppn is internally shifted 12 bits to the left
  constant sbase_PPN  : std_logic_vector(31 downto 0)  := x"000" & calc_sbase(IMSIC_ADDR, ncpu, groups, H_EN, vcpubits)(31 downto 12);
  constant mLHXS      : integer                        := 0;                                  -- Machine Low Hart Index Shift = C - 12 (see specs)
  constant sLHXS      : integer                        := vcpubits * H_EN;                    -- Supervisor Low Hart Index Shift = D - 12 (see specs)
  constant HHXS       : integer                        := ncpubits + vcpubits * H_EN - 12;    -- High Hart Index Shift = E - 24 (see specs)
  constant LHXW       : integer                        := ncpubits;                           -- Low Hart Index Width = k (see specs)
  constant HHXW       : integer                        := groupbits;                          -- High Hart Index Width = j (see specs)

  -- Signals
  -- AHB
  signal rhmbsel : std_logic_vector(0 to NAHBAMR-1);
  signal ahbov   : ahb_slv_out_vector_type(3 downto 0);
  -- PLIC Control
  signal plicirqt : std_logic_vector(nsources-1 downto 0);
  signal plicrstn, aplicrstn : std_ulogic;

  -- Outputs
  signal lirqi      : nv_irq_in_vector(0 to ncpu-1);
  signal imsic_irq  : imsic_irq_vector(0 to ncpu - 1);
  signal plic_irqo  : std_logic_vector(4*ncpu-1 downto 0);
  signal aplic_meip : std_logic_vector(0 to ncpu-1);
  signal aplic_seip : std_logic_vector(0 to ncpu-1);
  signal arst       : std_ulogic;
begin
  arst        <= ahbi.testrst when (ASYNC_RESET and scantest/=0 and ahbi.testen/='0') else
                 rstn when ASYNC_RESET else '1';

  -- ACLINT
  aclint_gen : if enable_aclint /= 0 generate
    aclint_ts_gen : if aclint_ts /= 0 generate
      aclint0 : aclint_ahb_ts
        generic map (
          hbaren    => 1,
          hindex    => hindex,
          hbar      => aclint_hbar,
          hirq1     => hirq1,
          hirq2     => hirq2,
          ncpu      => ncpu,
          mswi      => mswi,
          mtimer    => mtimer,
          mtimebits => mtimebits,
          asyncset  => asyncset,
          sswi      => sswi,
          watchdog  => watchdog,
          wdtickbit => wdtickbit,
          plicirqtreg => irqtype/2,
          plicrstreg  => enable_plic,
          aplicrstreg => enable_aplic,
          nsources  => nsources,
          plicirqtrst => irqtyperst,
          scantest  => scantest
          )
        port map (
          rst       => rstn,
          clk       => clk,
          timer     => timer,
          ahbi      => ahbi,
          ahbo      => ahbov(aclint_hbar),
          irqo      => lirqi,
          ack       => ack,
          ctrl      => ctrl,
          intcap    => interrupt_cap,
          plicirqt  => plicirqt,
          plicrstn  => plicrstn,
          aplicrstn => aplicrstn
          );
    end generate;
    aclint_rtc_gen : if aclint_ts = 0 generate
      aclint0 : aclint_ahb
        generic map (
          hbaren    => 1,
          hindex    => hindex,
          hbar      => aclint_hbar,
          hirq1     => hirq1,
          hirq2     => hirq2,
          ncpu      => ncpu,
          mswi      => mswi,
          mtimer    => mtimer,
          sswi      => sswi,
          watchdog  => watchdog,
          wdtickbit => wdtickbit,
          scantest  => scantest
          )
        port map (
          rst       => rstn,
          clk       => clk,
          rtc       => rtc,
          ahbi      => ahbi,
          ahbo      => ahbov(aclint_hbar),
          halt      => halt,
          irqo      => lirqi,
          intcap    => interrupt_cap
          );
      ctrl <= l5_tsc_ctrl_none;
    end generate;
  end generate;
  no_aclint_gen : if enable_aclint = 0 generate
    ahbov(aclint_hbar) <= ahbs_none;
    ctrl               <= l5_tsc_ctrl_none;
    lirqi              <= (others => nv_irq_in_none);
  end generate;


  -- IMSIC
  imsic_gen : if enable_imsic /= 0 generate
    imsic_ahb0 : imsic_ahb
      generic map (
        hindex     => hindex,
        hbaren     => 1,
        hbar       => imsic_hbar,
        ncpu       => ncpu,
        GEILEN     => GEILEN,
        groups     => groups,
        S_EN       => S_EN,
        H_EN       => H_EN,
        mnidentities_vector => nintid,
        snidentities_vector => nintid,
        gnidentities_vector => gnintid,
        scantest   => scantest
        )
      port map (
        rst       => rstn,
        clk       => clk,
        ahbi      => ahbi,
        ahbo      => ahbov(imsic_hbar),
        irq_ack   => irq_ack,
        irqo      => imsic_irq
        );
  end generate;
  no_imsic_gen : if enable_imsic = 0 generate
    ahbov(imsic_hbar) <= ahbs_none;
    imsic_irq         <= (others => imsic_irq_none);
  end generate;


  -- APLIC
  aplic_gen : if enable_aplic /= 0 generate
    aplic0 : graplic_ahb
      generic map (
        hmindex             => hmindex,
        hsindex             => hindex,
        hbaren              => 1,
        hbar                => aplic_hbar,
        nsources            => nsources-1,
        ncpu                => ncpu,
        branches            => branches,
        doms_per_branch     => doms_per_branch,
        endianness          => endianness,
        S_EN                => S_EN,
        H_EN                => H_EN,
        GEILEN              => H_EN*GEILEN,
        grouped_harts       => groups,
        mmsiaddrcfg_fixed   => mmsiaddrcfg_fixed,
        mbase_PPN           => mbase_PPN,
        sbase_PPN           => sbase_PPN,
        mLHXS               => mLHXS,
        sLHXS               => sLHXS,
        HHXS                => HHXS,
        LHXW                => LHXW,
        HHXW                => HHXW,
        direct_delivery     => direct_delivery,
        IPRIOLEN            => IPRIOLEN,
        nEIID               => neiid,
        leaf_domains        => leaf_domains,
        preset_active_harts => preset_active_harts,
        scantest            => scantest
        )
      port map (
        rstn        => rstn,
        clk         => clk,
        ahbmi       => ahbmi,
        ahbmo       => ahbmo,
        ahbsi       => ahbi,
        ahbso       => ahbov(aplic_hbar),
        softrstn    => aplicrstn,
        meip        => aplic_meip,
        seip        => aplic_seip
        );
  end generate;
  no_aplic_gen : if enable_aplic = 0 generate
    ahbov(aplic_hbar) <= ahbs_none;
    ahbmo             <= ahbm_none;
    aplic_meip        <= (others => '0');
    aplic_seip        <= (others => '0');
  end generate;


  -- PLIC
  plic_gen : if enable_plic /= 0 generate
    plic0 : grplic_ahb
      generic map (
        hindex      => hindex,
        hbaren      => 1,
        hbar        => plic_hbar,
        nsources    => nsources,
        ncpu        => ncpu,
        priorities  => priorities,
        pendingbuff => pendingbuff,
        irqtypeconf => irqtype,
        thrshld     => thrshld,
        scantest    => scantest
        )
      port map (
        rst         => rstn,
        clk         => clk,
        ahbi        => ahbi,
        ahbo        => ahbov(plic_hbar),
        irqtype     => plicirqt,
        softrstn    => plicrstn,
        irqo        => plic_irqo
        );
  end generate;
  no_plic_gen : if enable_plic = 0 generate
    ahbov(plic_hbar) <= ahbs_none;
    plic_irqo        <= (others => '0');
  end generate;

  -- hmbsel needs to be registered when a new
  -- transaction starts.
  syncrregs : if not ASYNC_RESET generate
    regs : process(clk)
    begin
      if rising_edge(clk) then
        if ahbi.hready = '1' then
          rhmbsel <= ahbi.hmbsel;
        end if;
        if rstn = '0' then
          rhmbsel <= (others => '0');
        end if;
      end if;
    end process;
  end generate;

  asyncrregs : if ASYNC_RESET generate
    regs : process(clk, arst)
    begin
      if arst = '0' then
        rhmbsel <= (others => '0');
      elsif rising_edge(clk) then
        if ahbi.hready = '1' then
          rhmbsel <= ahbi.hmbsel;
        end if;
      end if;
    end process;
  end generate;

  -- Multiplex slv output
  sel_ahbo: process(rhmbsel, ahbov)
  begin
    ahbo <= ahbs_none;
    for i in 0 to 3 loop
      if rhmbsel(i) = '1' then
        ahbo <= ahbov(i);
      end if;
    end loop;
    -- All bars share the same hconfig
    ahbo.hindex  <= hindex;
    ahbo.hconfig <= hconfig;
  end process;

  -- Outputs
  gen_outputs : for i in 0 to ncpu-1 generate
    irqi(i).mtip       <= lirqi(i).mtip;
    irqi(i).msip       <= lirqi(i).msip;
    irqi(i).ssip       <= lirqi(i).ssip;
    irqi(i).meip       <= plic_irqo(i*4);
    irqi(i).seip       <= plic_irqo(i*4+1);
    irqi(i).hgeip      <= (others => '0');
    irqi(i).stime      <= lirqi(i).stime;
    irqi(i).imsic      <= imsic_irq(i);
    irqi(i).aplic_meip <= aplic_meip(i);
    irqi(i).aplic_seip <= aplic_seip(i);
    irqi(i).nmirq      <= rnmi_irq((i+1)*NEXTNMIRQ-1 downto i*NEXTNMIRQ);
  end generate;

end;
