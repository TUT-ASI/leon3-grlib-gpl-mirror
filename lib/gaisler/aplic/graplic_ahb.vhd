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
-- Entity:      graplic_ahb
-- File:        graplic_ahb.vhd
-- Author:      Francisco Bas, Frontgrade Gaisler AB
-- Description: Advanced Plataform-Level Interrupt Controller (APLIC) designed
--              according to the specs described in the document:
--              The RISC-V Advanced Interrupt Architecture (Version 1.0-RC3)
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.conv_integer;
use grlib.stdlib.conv_std_logic_vector;
use grlib.stdlib.log2x;

library gaisler;
use gaisler.aplic.all;


entity graplic_ahb is
  generic (
    hmindex             : integer range 0 to NAHBMST-1   := 0;
    hsindex             : integer range 0 to NAHBSLV-1   := 0;
    haddr               : integer range 0 to 16#FFF#     := 0;
    nsources            : integer range 1 to MAX_SOURCES := 32;          -- Number of wired interrupt sources
    ncpu                : integer range 0 to MAX_HARTS   := 16;          -- Number of cpus in the system
    branches            : integer range 0 to 10          := 1;           -- Number of branches in the domain hirarchy
    doms_per_branch     : integer range 0 to MAX_DOMAINS := 3;           -- Number of domains in each branch
    endianness          : integer range 0 to 2           := 2;           -- 0 => little; 1 => big; 2 => bi
    S_EN                : integer range 0 to 1           := 1;           -- 0 => supervisor extension disable; 1 => supervisor extension enable
    H_EN                : integer range 0 to 1           := 1;           -- 0 => hipervisor extension disable; 1 => hipervisor extension enable
    GEILEN              : integer                        := 8;           -- System virtual guest external interrupt number 
    grouped_harts       : integer range 0 to 1           := 0;           -- If set to 1, harts are grouped 
    mmsiaddrcfg_fixed   : integer range 0 to 1           := 1;           -- If set to 1, registers mmsiaddrcfg/mmsiaddrcfgh/smsiaddrcfgh/smsiaddrcfgh are fixed
                                                                         -- and cannot be accessed. Their values are set through generics mLHXS/sLHXS/HHXS/LHXW/HHXW
    mbase_PPN           : std_logic_vector(31 downto 0)  := x"00000000"; -- Set the imsic base address for machine mode interrupts (only if mmsiaddrcfg_fixed = 0)
    sbase_PPN           : std_logic_vector(31 downto 0)  := x"00000000"; -- Set the imsic base address for supervisor mode interrupts (only if mmsiaddrcfg_fixed = 0)
    mLHXS               : integer                        := 0;           -- Machine Low Hart Index Shift = C - 12 (see specs)
    sLHXS               : integer                        := 0;           -- Supervisor Low Hart Index Shift = D - 12 (see specs)
    HHXS                : integer                        := 0;           -- High Hart Index Shift = E - 24 (see specs)
    LHXW                : integer                        := 0;           -- Low Hart Index Width = k (see specs)
    HHXW                : integer                        := 0;           -- High Hart Index Width = j (see specs)
    direct_delivery     : integer range 0 to 1           := 0;           -- If set to 0 direct delivery mode is not implemented 
    IPRIOLEN            : integer range 1 to 8           := 8;           -- IPRIO has values between 1 and 2^IPRIOLEN (used when there is no IMSIC and the APLIC acts as interrupt controller)
    nEIID               : integer range 1 to 2047        := 2047;        -- Number of External Interrupt identities (used when interrupts are forwarded to the IMSIC)
    leaf_domains        : std_logic_vector(MAX_DOMAINS-1 downto 0) := (others => '0'); -- Configures the leaf domains
    preset_active_harts : preset_active_harts_type                       -- Configures for each domain which cores are elegibles (through target registers) to forward the interrupts (Reset value)
    );
  port (
    rstn        : in  std_ulogic;
    clk         : in  std_ulogic;
    ahbmi       : in  ahb_mst_in_type;
    ahbmo       : out ahb_mst_out_type;
    ahbsi       : in  ahb_slv_in_type;
    ahbso       : out ahb_slv_out_type;
    meip        : out std_logic_vector(0 to ncpu-1);  -- Machine external interrupt bits when direct delivery mode is active (DM=0)
    seip        : out std_logic_vector(0 to ncpu-1)   -- Supervisor external interrupt bits when direct delivery mode is active (DM=0)
    );
end;


architecture rtl of graplic_ahb is


  -- Total number of APLIC domains
  constant ndomains : integer := branches*doms_per_branch+1;
  
  --------------------------------------------------------------------------------------------------
  -- Function definitions
  --------------------------------------------------------------------------------------------------


  -- It sets domaincfg.BE to 0 (little-endian) at reset when endianness is set to little endian (0)
  -- If it si set big endian or bi-endian, domaincfg.BE is set to 1 at reset (big-endian)
  function RES_BE(endianness : integer) return std_ulogic is
  begin 
    if endianness = 1 then
      return '1';
    else 
      return '0';
    end if;
  end function;

  -- It converts 32 bits vectors from little to big endian or the other way around
  function change_endianness(input_vector : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable output_vector : std_logic_vector(31 downto 0);
  begin 
    output_vector := input_vector(7 downto 0) & input_vector(15 downto 8) &
                     input_vector(23 downto 16) & input_vector(31 downto 24);
    return output_vector;
  end function;

  -- It resets  mmsiaddrcfg to one value or another depending if the registers
  -- mmsiaddrcfg and smsiaddrcfg are hardwire or not
  function RES_mmsiaddrcfg(fixed : integer) return mmsiaddrcfg_type is
    variable mmsiaddrcfg : mmsiaddrcfg_type;
  begin 
    if mmsiaddrcfg_fixed = 1 then
      mmsiaddrcfg := (
        base_ppn  => x"000" & mbase_ppn, 
        L         => '1',
        HHXS      => std_logic_vector(to_signed(HHXS, 5)),
        LHXS      => std_logic_vector(to_unsigned(mLHXS, 3)),
        HHXW      => std_logic_vector(to_unsigned(HHXW, 3)),
        LHXW      => std_logic_vector(to_unsigned(LHXW, 4))
      );
    else
      mmsiaddrcfg := (
        base_ppn  => (others => '0'),
        L         => '0',
        HHXS      => (others => '0'),
        LHXS      => (others => '0'),
        HHXW      => (others => '0'),
        LHXW      => (others => '0')
      );
    end if;
    return mmsiaddrcfg;
  end function;

  -- It resets mmsiaddrcfg to one value or another depending if the registers
  -- mmsiaddrcfg and smsiaddrcfg are hardwire or not
  function RES_smsiaddrcfg(fixed : integer) return smsiaddrcfg_type is
    variable smsiaddrcfg : smsiaddrcfg_type;
  begin 
    if mmsiaddrcfg_fixed = 1 then
      smsiaddrcfg := (
        base_ppn  => x"000" & sbase_ppn, --a0000000", --std_logic_vector(to_unsigned(mbase_ppn, 44)),
        LHXS      => std_logic_vector(to_unsigned(sLHXS, 3))
      );
    else
      smsiaddrcfg := (
        base_ppn  => (others => '0'),
        LHXS      => (others => '0')
      );
    end if;
    return smsiaddrcfg;
  end function;


  type active_harts_type is array (0 to ndomains-1) of std_logic_vector(ncpu-1 downto 0);
  
  function RES_active_harts(in_array : preset_active_harts_type) return active_harts_type is
    variable out_array :  active_harts_type;
  begin
    for i in out_array'range loop
      out_array(i) := in_array(i)(ncpu-1 downto 0);
    end loop;
    return out_array;
  end function; 

  function RES_domain_pmode(leaf_domains : std_logic_vector; S_EN : integer) return std_logic_vector is
    variable out_vec : std_logic_vector(0 to ndomains-1) := (others => '0');
  begin
    if S_EN = 1 then
      out_vec := leaf_domains;
    end if;
    return out_vec;
  end function;



  --------------------------------------------------------------------------------------------------
  -- Type and constant definitions 
  --------------------------------------------------------------------------------------------------

  constant dombits   : integer := log2x(ndomains);
  constant ncpubits  : integer := log2x(ncpu);
  constant nvcpubits : integer := log2x(GEILEN+1);
  constant eiidbits  : integer := log2x(nEIID);
  constant srcbits   : integer := log2x(nsources+1);

  constant zero32 : std_logic_vector(31 downto 0) := (others => '0');
  -- At the end of the memory region the harts masks of the domains are mapped
  constant hmask : integer range 0 to 16#FFF# := bits2hmask(15+log2x(ndomains+1));
  constant REVISION : integer := 0;

  constant hconfig : ahb_config_type := (
    0 => ahb_device_reg (VENDOR_GAISLER, GAISLER_GRAPLIC, 0, REVISION, 0), 
    4 => ahb_membar(haddr, '0', '0', hmask),
    others => zero32);

  -- Domains configured as leaf domains are set to 1
  constant leaf_doms : std_logic_vector(ndomains-1 downto 0) := set_leaf_doms(leaf_domains, branches, doms_per_branch);

  -- Sourcecfg type does not contain child_index field because current APLIC implementation only
  -- allows the root domain to have more than 1 child
  -- Apart from the D field, two extra fields are defined to determine when a sources is
  -- active or implmeented in a certain domain.
  -- Storing Source Mode (SM) field of the sourcecfg register for each of the sources in each domain
  -- would be redundant. Therfore a different type is created to store the source configuration.
  constant branch_bits : integer := log2x(branches);
  type index_vector is array (natural range <>) of std_logic_vector(branch_bits-1 downto 0);
  type sourcecfg_type is record
    D            : std_logic_vector(nsources downto 0);
    active       : std_logic_vector(nsources downto 0); -- source active in the domain
    implemented  : std_logic_vector(nsources downto 0); -- source implemented in the domain
  end record;
  type sourcecfg_vector is array (natural range <>) of sourcecfg_type;
  type sourcecfg_SM_vector is array (natural range <>) of std_logic_vector(2 downto 0);

  constant RES_sourcecfg : sourcecfg_type := (
    D           => (others => '0'),
    active      => (others => '0'),
    implemented => (others => '0')
  );

  type genmsi_type is record
    hart_index  : std_logic_vector(ncpubits-1 downto 0);
    busy        : std_ulogic;
    eiid        : std_logic_vector(eiidbits-1 downto 0);
  end record;
  type genmsi_vector is array (natural range <>) of genmsi_type;

  constant RES_genmsi : genmsi_type := (
    hart_index  => (others => '0'),
    busy        => '0',
    eiid        => (others => '0')
  );

  type target_type is record
    hart_index  : std_logic_vector(ncpubits-1 downto 0);
    guest_index : std_logic_vector(nvcpubits-1 downto 0);
    eiid        : std_logic_vector(eiidbits-1 downto 0);
    iprio       : std_logic_vector(IPRIOLEN-1 downto 0);
  end record;
  type target_vector is array (natural range <>) of target_type;


  type idc_type is record
    idelivery  : std_ulogic;
    iforce     : std_ulogic;
    ithreshold : std_logic_vector(IPRIOLEN-1 downto 0);
    topi_id    : std_logic_vector(srcbits-1 downto 0);
    topi_pri   : std_logic_vector(IPRIOLEN-1 downto 0);
  end record;
  type idc_vector is array (natural range <>) of idc_type;


  type hart_type is record
    dom    : std_logic_vector(dombits-1 downto 0);
    direct : std_ulogic;
  end record;
  type hart_dom  is array (ncpu-1 downto 0) of hart_type;
  type mode_hart_dom  is array (S_EN downto 0) of hart_dom;

  constant RES_hart_type : hart_type := (
    dom    => (others => '0'),
    direct => '0'
  );

  constant RES_idc : idc_type := (
    idelivery  => '0',
    iforce     => '0',
    ithreshold => (others => '0'),
    topi_id    => (others => '0'),
    topi_pri   => (others => '0')
  );


  -- Priority Encoder types (For direct delivery mode)
  type priority_in_type is array (nsources downto 1) of std_logic_vector(IPRIOLEN-1 downto 0);
  type priority_out_type is array (0 to ncpu*(1+S_EN)-1) of std_logic_vector(IPRIOLEN-1 downto 0);
  type enable_type is array (0 to ncpu*(1+S_EN)-1) of std_logic_vector(nsources downto 1);
  type id_type is array (0 to ncpu*(1+S_EN)-1) of std_logic_vector(srcbits-1 downto 0);


  constant RES_DM : std_ulogic := not(to_unsigned(direct_delivery, 1)(0));
  constant RES_domaincfg : domaincfg_type := (
    IE  => '0',
    DM  => RES_DM,
    BE  => RES_BE(endianness)
  );


  -- It resets mmsiaddrcfg to one value or another depending if the registers
  -- mmsiaddrcfg and smsiaddrcfg are hardwire or not
  function RES_target(active_harts : active_harts_type) return target_vector is
    variable rst_core : integer;
    variable RES_target_vec : target_vector(nsources downto 1);
  begin
    for i in ncpu-1 downto 0 loop
      if active_harts(0)(i) = '1' then
        rst_core := i;
      end if;
    end loop;
    for i in 1 to nsources loop
      RES_target_vec(i).hart_index := conv_std_logic_vector(rst_core, ncpubits);
      RES_target_vec(i).iprio := conv_std_logic_vector(1, IPRIOLEN);
      RES_target_vec(i).guest_index := (others => '0');
      RES_target_vec(i).eiid := (others => '0');
    end loop;
    return RES_target_vec;
  end function;


  type reg_type is record
    -- Interrupt domains registers
    domaincfg    : domaincfg_vector(ndomains-1 downto 0);
    child_index  : index_vector(nsources downto 0);   -- Only for the root domain
    sourcecfg    : sourcecfg_vector(ndomains-1 downto 0);
    src_active   : std_logic_vector(nsources downto 0);
    src_pmode    : std_logic_vector(nsources downto 0);
    src_dm       : std_logic_vector(nsources downto 0);
    sourcecfg_SM : sourcecfg_SM_vector(nsources downto 0); 
    mmsiaddrcfg  : mmsiaddrcfg_type;
    smsiaddrcfg  : smsiaddrcfg_type;
    setip        : std_logic_vector(nsources downto 0);
    setie        : std_logic_vector(nsources downto 0);
    genmsi       : genmsi_vector(ndomains-1 downto 0);
    target       : target_vector(nsources downto 1); 
    m_idc        : idc_vector(ncpu-1 downto 0);
    s_idc        : idc_vector(ncpu-1 downto 0);
    -- Direct deliver mode
    hart            : mode_hart_dom;
    -- encoder
    dm_id           : id_type;
    dm_ip           : std_logic_vector(0 to ncpu*(1+S_EN)-1);
    dm_pr_array     : priority_out_type;
    dm_enable       : enable_type;
    -- Interrupt source signals
    src_inverted  : std_logic_vector(nsources downto 0);
    src_rectified : std_logic_vector(nsources downto 0);
    -- Active harts per domain
    active_harts : active_harts_type;
    domain_pmode : std_logic_vector(ndomains-1 downto 0); -- domains priviledge mode; 0 => machine mode; 1 => supervisor mode
    -- MSI forwarding
    MSI_active   : std_logic_vector(nsources downto 0);
    -- AHB slave interface
    hsel        : std_logic_vector(1 downto 0);
    hready      : std_logic;
    hwrite      : std_logic;
    hsize       : std_logic_vector(2 downto 0);
    haddr       : std_logic_vector(31 downto 0);
    hresp       : std_logic_vector(1 downto 0);
    hwdata      : std_logic_vector(31 downto 0);
    hrdata      : std_logic_vector(31 downto 0);
    -- AHB master interface
    hmaddr      : std_logic_vector(31 downto 0);
    hmdata      : std_logic_vector(31 downto 0);
    next_wdata  : std_logic_vector(31 downto 0);
    domsi       : std_ulogic;
  end record;


  constant RES_T : reg_type := (
    -- Interrupt domains registers
    domaincfg   => (others => RES_domaincfg),
    child_index => (others => (others => '0')),
    sourcecfg   => (others => RES_sourcecfg),
    src_active  => (others => '0'),
    src_pmode   => (others => '0'),
    src_dm  => (others => '0'),
    sourcecfg_SM => (others => (others => '0')),
    mmsiaddrcfg => RES_mmsiaddrcfg(mmsiaddrcfg_fixed),
    smsiaddrcfg => RES_smsiaddrcfg(mmsiaddrcfg_fixed),
    setip       => (others => '0'),
    setie       => (others => '0'),
    genmsi      => (others => RES_genmsi),
    target      => RES_target(RES_active_harts(preset_active_harts)),
    m_idc       => (others => RES_idc),
    s_idc       => (others => RES_idc),
    -- Direct delivery mode
    hart            => (others => (others => RES_hart_type)),
    -- Priority encoder
    dm_id           => (others => (others => '0')),
    dm_ip           => (others => '0'),
    dm_pr_array     => (others => (others => '0')),
    dm_enable       => (others => (others => '0')),
    -- Interrupt source signals
    src_inverted  => (others => '0'),
    src_rectified => (others => '0'),
    -- Domains harts configuration
    active_harts  => RES_active_harts(preset_active_harts),
    domain_pmode  => RES_domain_pmode(leaf_doms, S_EN), -- By default all the leaf domains are supervisor domains
                                                        -- if S_EN = 1
    MSI_active    => (others => '0'),
    -- AHB slave interface
    hsel        => (others => '0'),
    hready      => '0',
    hwrite      => '0',
    hsize       => (others => '0'),
    haddr       => (others => '0'),
    hresp       => (others => '0'),
    hwdata      => (others => '0'),
    hrdata      => (others => '0'),
    -- AHB master interface
    hmaddr      => (others => '0'),
    hmdata      => (others => '0'),
    next_wdata  => (others => '0'),
    --start       => '0'
    domsi       => '0'
    );

  --------------------------------------------------------------------------------------------------
  -- Signals definition
  --------------------------------------------------------------------------------------------------

  -- AHB Master control signals
  signal ami : ahb_dma_in_type;
  signal amo : ahb_dma_out_type;

  -- Priority Encoder signals for direct delivery mode
  signal pr_array_unfold  : std_logic_vector((IPRIOLEN*nsources)-1 downto 0);
  signal dm_src_pri       : priority_in_type;
  signal dm_id            : id_type;
  signal dm_ip            : std_logic_vector(0 to ncpu*(1+S_EN)-1);
  signal dm_pr_array      : priority_out_type;

  -- Add register to improve timing paths. Adds one wait-state on
  -- Read and write accesses.
  constant pipe     : boolean := true;


  signal r, rin : reg_type;

begin
  

  -- Generic AHB master interface
  ahbmst0 : ahbmst
    generic map (hindex => hmindex, hirq => 0, venid => VENDOR_GAISLER,
                 devid => GAISLER_GRAPLIC, version => 0,
                 chprot => 3, incaddr => 0)
    port map (rstn, clk, ami, amo, ahbmi, ahbmo);


  -- Priority Encoders
  -- They are used for direct delivery mode
  -- Each hart has its own priority encoders 
  -- one for machine mode and one for supervisor mode (if active)
  encoders : for i in 0 to S_EN generate
    encoders : for j in 0 to ncpu-1 generate
      encoder : aplic_encoder
        generic map (
          nsources        => nsources,  
          srcbits         => srcbits,
          prbits          => IPRIOLEN
          )
        port map (
          rstn            => rstn,
          clk             => clk,
          ip              => r.setip(nsources downto 1),  -- In:  IP bit for every source
          pr_in           => pr_array_unfold,             -- In:  Each source's priority
          enable          => r.dm_enable(i*ncpu+j),       -- In:  Source enable signal (for this particular hart)
          id              => dm_id(i*ncpu+j),             -- Out: Identity of the hart interrupt with the highest priority
          ip_out          => dm_ip(i*ncpu+j),             -- Out: 1 when there is an interrupt pending and enable for the hart
          pr_out          => dm_pr_array(i*ncpu+j)        -- Out: Highest priority enable and pending interrupt                 
          );
    end generate;
  end generate;


  pr_unfolding : for i in 1 to nsources generate
    pr_array_unfold(i*IPRIOLEN-1 downto (i-1)*IPRIOLEN)  <= r.target(i).iprio;
  end generate;

  comb : process(r, ahbsi, amo, dm_ip, dm_id, dm_pr_array) is 
    variable v              : reg_type;
    variable irqi           : std_logic_vector(nsources-1 downto 0);
    variable hwdata         : std_logic_vector(31 downto 0);
    variable hrdata         : std_logic_vector(31 downto 0);
    variable wdata          : std_logic_vector(31 downto 0);
    variable rdata          : std_logic_vector(31 downto 0);
    variable struct_off     : std_logic_vector(14 downto 14);
    variable seldom         : integer;
    variable selsrc_reg     : integer;
    variable selsrc         : integer;
    variable selhart        : integer;
    variable sel_dommask    : integer;
    variable setnum         : integer;
    variable first_active_hart : integer;
    variable meip_tmp, seip_tmp : std_logic_vector(0 to ncpu-1);
    variable MSI_pending    : std_logic_vector(nsources downto 0);
    variable MSI_source     : integer;
    variable MSI_pmode      : std_ulogic;
    variable MSI_hart       : std_logic_vector(ncpubits-1 downto 0);
    variable MSI_guest_hart : std_logic_vector(nvcpubits-1 downto 0);
    variable next_wdata     : std_logic_vector(31 downto 0);
    variable next_addr      : std_logic_vector(31 downto 0);
    variable hart_index     : integer range 0 to ncpu;
    variable MSI_domain     : integer range 0 to ndomains-1;
    variable active_domain  : integer range 0 to ndomains-1;
    variable branch         : integer;
    variable active_genmsi  : std_ulogic;
    variable ahbreq         : std_ulogic;
    variable triggered_src  : std_logic_vector(nsources downto 0);
    variable supervisor_src : std_logic_vector(nsources downto 0); 
    variable LHXS_int       : integer;
    variable LHXW_int       : integer;
    variable HHXW_int       : integer;
    variable HHXS_int       : integer;
    variable g, h, guest_index : unsigned(31 downto 0) := (others => '0');
  begin
    


    v := r;

    v.hsel    := (others => '0');
    v.hready  := '1';
    v.hresp   := HRESP_OKAY; 

    rdata  := (others => '0');
    ahbreq := '0';
    
    -------------------------------------------------------------------------------------------------------------
    -- Interrupt forwarding logic and AHB master interface ------------------------------------------------------
    -------------------------------------------------------------------------------------------------------------
    irqi := ahbsi.hirq;


    --## DOMAIN HIERARCHY AND INTERRUPT DELEGATION #######################################################
    -- According to the specs:
    -- For an interrupt domain below the root, interrupt sources not delegated down to that domain appear
    -- to the domain as being NOT IMPLEMENTED.
    -- An interrupt source is inactive in the interrupt domain if either the source is delegated to a child
    -- domain (D = 1) or it is not delegated (D = 0) and SM is Inactive
     
    -- This code determines for each domain which of the interrupts sources are active/inactive, 
    -- implmentid/not implmented. This information is needed since domain configuration fields will affect
    -- only the domain active sources. Also the value of some registers depend on the state of the source within 
    -- the domain. 
    
    -- This part of the code determines how the hierarchy of domains is handled and which hierarchies are allowed.
    -- This concrete implementation allowes the root domain to have as many childs as needed. The rest of the
    -- domains can have only one child domain. This is translated in a domain hierarchy with an arbitray number of 
    -- branches each one with an arbitrary number of domains.

    for j in 1 to nsources loop 
      active_domain := 0;
      v.sourcecfg(0).active(j) := '0';
      for i in ndomains-1 downto 1 loop
        -- set to 0 all source active bits in all domains
        v.sourcecfg(i).active(j) := '0';
        if is_head(i, doms_per_branch) then
          branch := get_branch(i, doms_per_branch);
          -- Since the root domain can have several childs this is a special case where the domain delegetaion
          -- depends on the domain 0 and not on the previous domain state
          if r.sourcecfg(0).D(j) = '1' and unsigned(r.child_index(j)) = branch and r.sourcecfg(i).D(j) = '0' then
            active_domain := i;
          end if;
        else
          -- If the parent domain delegates the interrupt, the interrupt is active
          -- if SM different than inactive
          if r.sourcecfg(i).D(j) = '0' and r.sourcecfg(i-1).D(j) = '1' then
            active_domain := i;
          end if;
        end if;
      end loop;
      if r.sourcecfg(0).D(j) = '0' then
        active_domain := 0;
      end if;
      if r.sourcecfg_SM(j) /= "000" then -- It is not configured inactive 
        v.sourcecfg(active_domain).active(j) := '1';
      end if;
      for i in 1 to ndomains-1 loop
        branch := get_branch(i, doms_per_branch);
        if i <= active_domain and unsigned(r.child_index(j)) = branch then
          v.sourcecfg(i).implemented(j) := '1';
        else
          -- when source is not implemented in the domain sourcfg register is read-only 
          -- zero and remains zero even when the source is delegated from the parent
          v.sourcecfg(i).implemented(j) := '0';
          v.sourcecfg(i).D(j) := '0';
        end if;
      end loop;
      -- Sources in domain 0 are always implmented by definition
      v.sourcecfg(0).implemented(j) := '1';
    end loop;




    --## IE AND IP BITS ##################################################################################

    -- Determine for each source if it is active or not
    -- Determine for each source if it is configured as direct delivery mode or MSI
    v.src_dm     := (others => '0'); 
    v.src_active := (others =>'0');
    v.src_pmode  := (others =>'0');
    for i in 0 to ndomains-1 loop
      for j in 1 to nsources loop
        if r.sourcecfg(i).active(j) = '1' then
          v.src_active(j) := '1';
          if r.domaincfg(i).DM = '1' then
            v.src_dm(j) := '1';
          end if;
          if S_EN = 1 then
            if leaf_doms(i) = '1' then
              v.src_pmode(j) := '1';
            end if;
          end if;
        end if;
      end loop;
    end loop;


    -- Taking as an input the state of each source (active/inactive), its configuration
    -- and the state of the interrupt source inputs, calculate IP and IE bits for each sources.
    v.src_rectified(nsources downto 1) := r.src_inverted(nsources downto 1) xor irqi;
    for i in 1 to nsources loop
      if r.sourcecfg_SM(i) = detached or r.sourcecfg_SM(i) = inactive then
        v.src_rectified(i) := '0';
      end if;
    end loop;
    v.setip := (others => '0');
    v.setie := (others => '0'); -- IE bits set to 1 only if source is active
    triggered_src := (not r.src_rectified) and v.src_rectified; 
    for j in 1 to nsources loop 
      if r.src_active(j) = '1' then
        v.setie(j) := r.setie(j);
        case r.sourcecfg_SM(j) is
          when edge0 | edge1 =>
            v.setip(j) := r.setip(j) or triggered_src(j);
          when level0 | level1 =>
            if r.src_dm(j) = '1' then
              v.setip(j) := (r.setip(j) or triggered_src(j)) and v.src_rectified(j);
            else
              v.setip(j) := v.src_rectified(j);
            end if;
          when others => -- r.sourcecfg_SM(j) = detached
            v.setip(j) := r.setip(j);
        end case;
      else 
        v.setip(j) := '0';
        v.setie(j) := '0';
      end if;
    end loop;


    --## DIRECT DELIVERY MODE FORWARDING LOGIC ###########################################################

    meip_tmp := (others => '0');
    seip_tmp := (others => '0');


    if direct_delivery = 1 then

      -- If the interrupt controller for any hart is the APLIC configured in direct
      -- delivery mode, that hart is active in only one domain. 
      -- Determine for each hart if the interrupt controller is the aplic configured
      -- in direct delivery mode and if so, which domain handles their interrupts
      v.hart := (others => (others => RES_hart_type));
      for i in 0 to ncpu-1 loop
        for j in 0 to ndomains-1 loop
          if r.active_harts(j)(i) = '1' and r.domaincfg(j).DM = '0' then
            if r.domain_pmode(j) = '0' or S_EN = 0 then
              -- Machine mode
              v.hart(0)(i).dom := conv_std_logic_vector(j, dombits);
              v.hart(0)(i).direct := '1'; --not(r.domaincfg(j).DM);
            else
              -- Supervisor mode
              v.hart(1)(i).dom := conv_std_logic_vector(j, dombits);
              v.hart(1)(i).direct := '1'; --not(r.domaincfg(j).DM);
            end if;
          end if;
        end loop;
      end loop;


      -- Compute the enable interrupt source signals (priority encoder input) 
      -- for each hart and each mode (machine/supervisor)
      for i in 0 to ncpu-1 loop
        for j in 0 to S_EN loop
          for k in nsources downto 1 loop
            v.dm_enable(j*ncpu+i)(k) := '0';
            if r.hart(j)(i).direct = '1' then
              if unsigned(r.target(k).hart_index) = i and r.src_active(k) = '1' then
                if j = conv_integer(r.src_pmode(k)) then
                  v.dm_enable(j*ncpu+i)(k) := r.setie(k);
                end if;
              end if;
            end if;
          end loop;
        end loop;
      end loop; 


      -- priority enconcer outputs
      v.dm_id        := dm_id;
      v.dm_ip        := dm_ip;
      v.dm_pr_array  := dm_pr_array;


      -- Set the topi register if there is an enble and pending interrupt and if the conditions are met forward the interrupt
      for i in 0 to ncpu-1 loop
        v.m_idc(i).topi_id  := (others => '0');
        v.m_idc(i).topi_pri := (others => '0');
        v.s_idc(i).topi_id  := (others => '0');
        v.s_idc(i).topi_pri := (others => '0');
        -- Machine
        if (unsigned(r.dm_pr_array(i)) < unsigned(r.m_idc(i).ithreshold) or unsigned(r.m_idc(i).ithreshold) = 0) and r.dm_ip(i) = '1' then
          v.m_idc(i).topi_id  := r.dm_id(i);
          v.m_idc(i).topi_pri := r.dm_pr_array(i);
        end if;
        if r.m_idc(i).idelivery = '1' and r.domaincfg(conv_integer(r.hart(0)(i).dom)).IE = '1' and (unsigned(r.m_idc(i).topi_pri) /= 0 or r.m_idc(i).iforce = '1') then
          meip_tmp(i) := '1';
        end if;
        -- Supervisor
        if S_EN = 1 then
          if (unsigned(r.dm_pr_array(ncpu+i)) < unsigned(r.s_idc(i).ithreshold) or unsigned(r.s_idc(i).ithreshold) = 0) and r.dm_ip(ncpu+i) = '1' then
            v.s_idc(i).topi_id  := r.dm_id(ncpu+i);
            v.s_idc(i).topi_pri := r.dm_pr_array(ncpu+i);
          end if;
          if r.s_idc(i).idelivery = '1' and r.domaincfg(conv_integer(r.hart(1)(i).dom)).IE = '1' and (unsigned(r.s_idc(i).topi_pri) /= 0 or r.s_idc(i).iforce = '1') then
            seip_tmp(i) := '1';
          end if;
        end if;
      end loop;
      ----------------------------------------------------------------------------------------------------------

    end if;



    -- ## MSI FORWARDING LOGIC ############################################################################
    -- If domain IE is set to 0 or direct delivery mode is active
    -- pending interrupts of that domain shouldn't be signaled through
    -- the bus.
    -- For each source determine if it should be forwarde by an MSI if
    -- its IE and IP bits are set. Also for each source determine if it
    -- is delegated to a supervisor or machine mode domain.
    supervisor_src := (others => '0'); 
    v.MSI_active := (others => '0');
    for i in 0 to ndomains-1 loop
      if r.domain_pmode(i) = '1' then
        supervisor_src := supervisor_src or r.sourcecfg(i).active;
      end if;
      if r.domaincfg(i).IE = '1' and r.domaincfg(i).DM = '1' then
          v.MSI_active := v.MSI_active or r.sourcecfg(i).active; 
      end if;
    end loop;


    -- It determines which interrupt to forward next by MSI
    MSI_pending := r.MSI_active and r.setip and r.setie;
    MSI_source  := 0;
    for i in nsources downto 1 loop
      if MSI_pending(i) = '1' then
        MSI_source := i;
      end if;
    end loop;

    -- Check if there is any extempore MSI pending (genmsi) 
    MSI_domain := 0;
    active_genmsi := '0';
    for i in 0 to ndomains-1 loop
      if r.genmsi(i).busy = '1' then
        MSI_domain := i;
        active_genmsi := '1';
      end if;
    end loop;

    -- If there is any pending interrupt to be signaled trhough MSI
    -- set domsi to 1 to and set the data and the address of the AHB transaction
    next_addr  := (others => '0');
    next_wdata := (others => '0');
    MSI_pmode  := '0';
    MSI_hart   := (others => '0');
    MSI_guest_hart := (others => '0');
    g := (others => '0');
    h := (others => '0');
    guest_index := (others => '0');
    if MSI_source /= 0 or active_genmsi = '1' then
      v.domsi := '1';
      if active_genmsi = '1' then
        MSI_hart := r.genmsi(MSI_domain).hart_index;
        next_wdata(eiidbits-1 downto 0) := r.genmsi(MSI_domain).eiid; 
        MSI_pmode := r.domain_pmode(MSI_domain);
      else
        MSI_hart := r.target(MSI_source).hart_index;
        MSI_guest_hart := r.target(MSI_source).guest_index;
        next_wdata(eiidbits-1 downto 0) := r.target(MSI_source).eiid;
        MSI_pmode := supervisor_src(MSI_source);
--pragma translate_off
        -- Check that a interrupt is never sent to a "illegal" core
        for i in 0 to ndomains-1 loop
          if r.sourcecfg(i).active(MSI_source) = '1' then
            assert r.active_harts(i)(conv_integer(MSI_hart)) = '1'
            report "An interrupt was forwarded to a illegal core." severity failure;
          end if;
        end loop;
        assert unsigned(MSI_guest_hart) = 0 or MSI_pmode = '1'
        report "An interrupt was forwarded to a virtual hart when the domain priviledge mode was machine mode" severity failure;
--pragma translate_on
      end if;
      HHXW_int := to_integer(unsigned(r.mmsiaddrcfg.HHXW));
      HHXS_int := to_integer(signed(r.mmsiaddrcfg.HHXS));
      LHXW_int := to_integer(unsigned(r.mmsiaddrcfg.LHXW));
      if MSI_pmode = '0' or S_EN = 0 then -- machine mode domain 
        LHXS_int := to_integer(unsigned(r.mmsiaddrcfg.LHXS));
        if grouped_harts = 0 then
          -- h = Hart_Index & (2^LHXW − 1)
          -- MSI_address = Base_PPN | (h<<LHXS) <<12
          ---------------------------------------------------------------------------------------------------------
          h := resize(unsigned(MSI_hart), 32);
          next_addr := r.mmsiaddrcfg.base_ppn(31 downto 0) or std_logic_vector(shift_left(h, 12+LHXS_int));
        else
          -- g = (Hart_Index>>LHXW) & (2^HHXW − 1)
          -- h = Hart_Index & (2^LHXW − 1)
          -- MSI_address = Base PPN | ((g<<(HHXS + 12)) | (h<<LHXS)) <<12
          ---------------------------------------------------------------------------------------------------------
          h := resize(unsigned(MSI_hart), 32) and to_unsigned(2 ** LHXW_int-1, 32); 
          h := shift_left(h, 12+LHXS_int);
          g := shift_right(resize(unsigned(MSI_hart), 32), LHXW_int) and to_unsigned(2 ** HHXW_int-1, 32); 
          g := shift_left(g, 12+(12+HHXS_int));
          next_addr := r.mmsiaddrcfg.base_ppn(31 downto 0) or std_logic_vector(g) or std_logic_vector(h);
        end if;
      else -- supervisor mode 
        LHXS_int := to_integer(unsigned(r.smsiaddrcfg.LHXS));
        if grouped_harts = 0 then
          -- h = machine-level hart index & (2 LHXW − 1)
          -- MSI address = Base PPN | ((h<<LHXS) | Guest Index) <<12 
          h := resize(unsigned(MSI_hart), 32) and to_unsigned(2 ** LHXW_int-1, 32); 
          h := shift_left(h, 12+LHXS_int);
          guest_index := shift_left(resize(unsigned(MSI_guest_hart), 32), 12);
          next_addr := r.smsiaddrcfg.base_ppn(31 downto 0) or std_logic_vector(h) or std_logic_vector(guest_index);
        else
          -- g = (machine-level hart index>>LHXW) & (2 HHXW − 1)
          -- h = machine-level hart index & (2 LHXW − 1)
          -- MSI address = Base PPN | ((g<<(HHXS + 12)) | (h<<LHXS) | Guest Index) <<12 
          h := resize(unsigned(MSI_hart), 32) and to_unsigned(2 ** LHXW_int-1, 32); 
          h := shift_left(h, 12+LHXS_int);
          g := shift_right(resize(unsigned(MSI_hart), 32), LHXW_int) and to_unsigned(2 ** HHXW_int-1, 32); 
          g := shift_left(g, 12+(12+HHXS_int));
          guest_index := shift_left(resize(unsigned(MSI_guest_hart), 32), 12);
          next_addr := r.smsiaddrcfg.base_ppn(31 downto 0) or std_logic_vector(g) or std_logic_vector(h) or std_logic_vector(guest_index);
        end if;
      end if;
    end if;

    -- When r.domsi = 1 perform the AHB write to the IMSIC 
    if r.domsi = '1' then
      if amo.active = '1' then
        if amo.ready = '1' then
          if active_genmsi = '1' then
            v.genmsi(MSI_domain).busy := '0';
          else
            v.setip(MSI_source) := '0';
          end if;
          v.domsi := '0';
        end if;
      else
        ahbreq := '1';
      end if;
    end if;
 
   
    -- An MSI’s 32-bit data is always written in little-endian byte order, 
    -- regardless of the BE field of the domain’s domaincfg register 

    -- Signal assignation to AHB master interface
    ami.address   <= next_addr;
    ami.wdata     <= ahbdrivedata(next_wdata);
    ami.start     <= ahbreq;
    ami.burst     <= '0';
    ami.write     <= '1';
    ami.busy      <= '0';
    ami.irq       <= '0';
    ami.size      <= "010"; -- 32 bit writes



  ----------------------------------------------------------------------------
  -- AHB slave interface
  ----------------------------------------------------------------------------

  --  Registers of the first 16 KiB of an interrupt domain’s memory-mapped control region|
  ---------------------------------------------------------------------------------------|
  --  offset     size        register name                                               |
  --                                                                                     |   
  --  0x0000     4 bytes     domaincfg          |                                        |
  --  0x0004     4 bytes     sourcecfg[1]       |                                        |
  --  0x0008     4 bytes     sourcecfg[2]       |                                        |
  --  ...                    ...                |                                        |
  --  0x0FFC     4 bytes     sourcecfg[102      |                                        |
  --  0x1BC0     4 bytes     mmsiaddrcfg        |                                        |
  --  0x1BC4     4 bytes     mmsiaddrcfgh       |                                        |
  --  0x1BC8     4 bytes     smsiaddrcfg        |                                        |
  --  0x1BCC     4 bytes     smsiaddrcfgh       |                                        |
  --  0x1C00     4 bytes     setip[0]           |                                        |
  --  0x1C04     4 bytes     setip[1]           |                                        |
  --  ...                    ...                |                                        |
  --  0x1C7C     4 bytes     setip[31]          |                                        |
  --  0x1CDC     4 bytes     setipnum           |                                        |
  --  0x1D00     4 bytes     in_clrip[0]        |                                        |
  --  0x1D04     4 bytes     in_clrip[1]        | => 16 KiB                              |
  --  ...                    ...                |                                        |
  --  0x1D7C     4 bytes     in_clrip[31]       |                                        |
  --  0x1DDC     4 bytes     clripnum           |                                        |
  --  0x1E00     4 bytes     setie[0]           |                                        |
  --  0x1E04     4 bytes     setie[1]           |                                        |
  --  ...                    ...                |                                        | => 32 KiB
  --  0x1E7C     4 bytes     setie[31]          |                                        |    Per domain
  --  0x1EDC     4 bytes     setienum           |                                        |
  --  0x1F00     4 bytes     clrie[0]           |                                        |
  --  0x1F04     4 bytes     clrie[1]           |                                        |
  --  ...                    ...                |                                        |
  --  0x1F7C     4 bytes     clrie[31]          |                                        |
  --  0x1FDC     4 bytes     clrienum           |                                        |
  --  0x2000     4 bytes     setipnum_le        |                                        |
  --  0x2004     4 bytes     setipnum_be        |                                        |
  --  0x3000     4 bytes     genmsi             |                                        |
  --  0x3004     4 bytes     target[1]          |                                        |
  --  0x3008     4 bytes     target[2]          |                                        |
  --  ...                    ...                |                                        |
  --  0x3FFC     4 bytes     target[1023]       |                                        |
  --                                                                                     |    
  --  Interrupt delivery control (IDC) structures                                        |
  ---------------------------------------------------                                    |
  --                                                                                     |    
  --  offset     size        register name                                               |
  --                                                                                     |    
  -- HART 1                                     |                                        |
  --  0x4000     4 bytes     idelivery          |                                        |
  --  0x4004     4 bytes     iforce             |                                        |
  --  0x4008     4 bytes     ithreshold         |                                        |
  --  0x4018     4 bytes     topi               | => 16 KiB (Max. 512 harts per domain)  |
  --  0x401C     4 bytes     claimi             |    If idc is not implemented           |
  --                                            |    (direct_delivery = 0), all the      |    
  -- HART 2                                     |    idc registers are read-only zero    |
  --  0x4020     4 bytes     idelivery          |                                        |
  --  0x4024     4 bytes     iforce             |                                        |
  --  0x4028     4 bytes     ithreshold         |                                        |
  --  0x4038     4 bytes     topi               |                                        |
  --  0x403C     4 bytes     claimi             |                                        |
  --                                            |                                        |   
  -- .... untill the last phsycal hart                                                   |
  --
  
  -- At the end of the last implemented domain there are several registers employed to configure to which
  -- hart each domain can forward interrupts to. Currently this configuration admits a maximum of 32 harts.
  -- If more harts are required a small modification is required.
  -- These registers offset start at address Hart_Mask_Offset=(0x8000*number_of_implemented_domains)

  --  offset     size        register name                                                 |
  --                                                                                       |    
  -- HMO+0x00    4 bytes     Hart Mask Domain[0]  |                                        |
  -- HMO+0x04    4 bytes     Hart Mask Domain[1]  |                                        |
  --  ...                    ...                  |                                        |
  -- HMO+0x04*Domain[n]      Hart Mask Domain[n]  |                                        |

  -- Each bit of each register configures one core. If bit 0 (LSB) of Hart Mask Domain[0] register is set to
  -- 1, Domain 0 can configure interrupts to be forwarded to core 0.
  -- It is important to configure each domain to be able to send interrupts to at least on core. If not,
  -- this domain will be able to send interrupts to core 0 even if it is not intended to.
  -- If the external interrupt controller of one hart is an APLIC domain configured as Direct Delivery Mode,
  -- only this domain should be able to send interrupts to the hart. It is responsibility of the software
  -- to set these registers properly.


  -- In the following diagram each square represents an APLIC domain and the number inside the square
  -- represents the domain number. APLIC domains are arranged contigously in the memory map. That is to
  -- say, the domain 0 is in the offset 0x00000000, the domain 1 is in the offset 0x00008000, the domain
  -- 2 is in the offset 0x00010000, the domain 3 is in the offset 0x00018000 and so on. As mentioned before, 
  -- APLIC can be configured to have an arbitrary number of branches and an arbitrary number of domains per branch.
  -- 
  --                                        |-----|
  --                                        |  0  |
  --                                        |--|--|
  --                                           |
  --                    B0            B1       |                     BN
  --                     |-------------|-------|-------|--------------|
  --                     |             |               |              |
  --                     |             |               |              |
  --                  |--|--|       |--|--|            |           |--|--|
  --                  |  1  |       |  4  |          .....         |N*3+1|
  --                  |--|--|       |--|--|            |           |--|--|
  --                     |             |               |              |
  --                     |             |               |              |
  --                  |--|--|       |--|--|            |           |--|--|
  --                  |  2  |       |  5  |          .....         |N*3+2|
  --                  |--|--|       |--|--|                        |--|--|
  --                     |             |               |              |
  --                     |             |               |              |
  --                  |--|--|       |--|--|            |           |--|--|
  --                  |  3  |       |  6  |          .....         |N*3+3|
  --                  |--|--|       |--|--|                        |--|--|




  -- Only naturally aligned 32-bit simple reads and writes are supported within an interrupt 
  -- domain’s control region. Writes to read-only bytes are ignored. For other forms of accesses 
  -- (other sizes, misaligned accesses, or AMOs), implementations should preferably report an 
  -- access fault or bus error but must otherwise ignore the access.

    struct_off  := r.haddr(struct_off'range);
    seldom      := conv_integer(r.haddr(calc_upperLimit(15+dombits)-1 downto 15));
    selsrc_reg  := conv_integer(r.haddr(7 downto 2));
    selsrc      := conv_integer(r.haddr(11 downto 2));
    selhart     := conv_integer(r.haddr(13 downto 5));
    --sel_dommask := conv_integer(r.haddr(dombits+2-1 downto 2));
    sel_dommask := conv_integer(r.haddr(14 downto 2));

    hwdata := ahbsi.hwdata(31 downto  0); -- Only 32 bits accesses are allowed

    -- Slave selected
    if (ahbsi.hready and ahbsi.hsel(hsindex) and ahbsi.htrans(1)) = '1' then
      v.hsel(0)  := '1';
      v.haddr    := ahbsi.haddr;
      v.hsize    := ahbsi.hsize;
      v.hwrite   := ahbsi.hwrite;
      -- pipe
      if pipe then
        v.hready   := '0';
      end if;
    end if;

    -- Write data
    if pipe then
      if r.hsel(0) = '1' and r.hwrite = '1' then
        v.hwdata := hwdata;
      end if;
      wdata := r.hwdata;
      v.hsel(1) := r.hsel(0);
    else
      wdata := hwdata;
      v.hwdata := (others => '0');
      v.hsel(1) := v.hsel(0);
    end if;

    -- Read access
    if r.hsel(0) = '1' and r.hwrite = '0' and r.hsize = "010" then -- Transfer size must be 32 bits long
      if seldom < ndomains then
        if struct_off = "0" then -- First 16 KiB registers (non-IDC registers)
          case r.haddr(13 downto 12) is
            when "00" =>
              if r.haddr(11 downto 0) = x"000" then -- domaincfg  (0x0000)
                rdata(31 downto 24) := x"80";
                rdata(8) := r.domaincfg(seldom).IE;
                rdata(2) := r.domaincfg(seldom).DM;
                if endianness = 0 then -- little-endian
                  rdata(0) := '0'; -- read-only
                elsif endianness = 1 then -- big-endian
                  rdata(0) := '1'; -- read-only
                else -- bi-endian
                  rdata(0) := r.domaincfg(seldom).BE; 
                end if;
              elsif selsrc <= nsources then -- sourcecfg[1] to sourcecfg[1024]
                if r.sourcecfg(seldom).implemented(selsrc) = '1' then
                  if r.sourcecfg(seldom).D(selsrc) = '1' then
                    rdata(10) := '1'; 
                    if seldom = 0 then
                      rdata(branch_bits-1 downto 0) := r.child_index(selsrc);
                    end if;
                  else
                    rdata(10) := '0'; 
                    rdata(2 downto 0) := r.sourcecfg_SM(selsrc);
                  end if;
                end if;
              end if;
            when "01" => 
              case r.haddr(11 downto 8) is
                when x"B" => -- addrcfg
                  if seldom = 0 then -- Registers only implemented for the root domain
                    case r.haddr(7 downto 0) is
                      when x"C0" => -- mmsiaddrcfg   (0x1BC0)
                        if r.mmsiaddrcfg.L = '0' then
                          rdata := r.mmsiaddrcfg.base_ppn(31 downto 0);
                        end if;
                      when x"C4" => -- mmsiaddrcfgh  (0x1BC4)
                        if r.mmsiaddrcfg.L = '0' then
                          rdata(31) := '0';
                          rdata(28 downto 24) := r.mmsiaddrcfg.HHXS;
                          rdata(22 downto 20) := r.mmsiaddrcfg.LHXS;
                          rdata(18 downto 16) := r.mmsiaddrcfg.HHXW;
                          rdata(15 downto 12) := r.mmsiaddrcfg.LHXW;
                          rdata(11 downto 0)  := r.mmsiaddrcfg.base_ppn(43 downto 32);
                        else
                          rdata(31) := '1';
                        end if;
                      when x"C8" => -- smsiaddrcfg   (0x1BC8)
                        if r.mmsiaddrcfg.L = '0' and unsigned(r.domain_pmode) /= 0 then -- There is at least one supervisor-level interrupt domain
                          rdata := r.smsiaddrcfg.base_ppn(31 downto 0);
                        end if;
                      when x"CC" => -- smsiaddrcfgh  (0x1BCC)
                        if r.mmsiaddrcfg.L = '0' and unsigned(r.domain_pmode) /= 0 then -- There is at least one supervisor-level interrupt domain
                          rdata(22 downto 20) := r.smsiaddrcfg.LHXS;
                          rdata(11 downto 0)  := r.smsiaddrcfg.base_ppn(43 downto 32);
                        end if;
                      when others =>
                    end case;
                  end if;
                when x"C" => -- setip
                  if r.haddr(7 downto 0) = x"DC" then -- setipnum (0x1CDC)
                    -- A read always return zero
                  else -- setip[0] to setip[31]
                    for i in 1 to nsources loop
                      if i/32 = selsrc_reg then
                        rdata(i mod 32) := r.sourcecfg(seldom).active(i) and r.setip(i);
                      end if;
                    end loop;
                  end if;
                when x"D" => -- clrip
                  if r.haddr(7 downto 0) = x"DC" then -- clripnum (0x1DDC)
                    -- A read always return zero
                  else -- in_clrip[0] to in_clrip[31]
                    for i in 1 to nsources loop
                      if i/32 = selsrc_reg then
                        rdata(i mod 32) := r.sourcecfg(seldom).implemented(i) and v.src_rectified(i);
                      end if;
                    end loop;
                  end if;
                when x"E" => -- setie
                  if r.haddr(7 downto 0) = x"DC" then -- setienum (0x1EDC)
                    -- A read always return zero
                  else -- setie[0] to setie[31]
                    for i in 1 to nsources loop
                      if i/32 = selsrc_reg then
                        rdata(i mod 32) := r.sourcecfg(seldom).active(i) and r.setie(i);
                      end if;
                    end loop;
                  end if;
                when x"F" => -- clrienum and clrie[0] to clrie[31]
                when others =>
              end case;
            when "10" =>
              case r.haddr(7 downto 0) is
                when x"00" => -- setipnum_le (0x2000)
                  -- A read always return zero
                when x"04" => -- setipnum_be (0x2004)
                  -- A read always return zero
                when others =>
              end case;
            when others => -- only "11" left
              if r.haddr(11 downto 2) = x"00" & "00" then -- genmsi (0x3000)
                -- When the interrupt domain is configured in direct delivery mode 
                -- (domaincfg.DM = 0), register genmsi is read-only zero
                if r.domaincfg(seldom).DM = '1' then 
                  rdata(18+ncpubits-1 downto 18) := r.genmsi(seldom).hart_index;
                  rdata(12)                      := r.genmsi(seldom).busy;
                  rdata(eiidbits-1 downto 0)     := r.genmsi(seldom).EIID;
                end if;
              elsif selsrc <= nsources then -- target[1] to target[1023]
                if r.sourcecfg(seldom).active(selsrc) = '1' then
                  if r.domaincfg(seldom).DM = '0' then
                    rdata(18+ncpubits-1 downto 18) := r.target(selsrc).hart_index; 
                    rdata(IPRIOLEN-1 downto 0)   := r.target(selsrc).iprio; 
                  else
                    rdata(18+ncpubits-1 downto 18) := r.target(selsrc).hart_index; 
                    if H_EN = 1 and r.domain_pmode(seldom) = '1' then
                      rdata(12+nvcpubits-1 downto 12) := r.target(selsrc).guest_index; 
                    end if;
                    rdata(eiidbits-1 downto 0)  := r.target(selsrc).EIID; 
                  end if;
                end if;
              end if;
          end case;
        elsif direct_delivery = 1 then -- Interrupt delivery control (IDC) structure 
          if selhart < ncpu and r.active_harts(seldom)(selhart) = '1' then
            case r.haddr(4 downto 2) is
              when "000" =>  -- idelivery (0x00)
                if r.domain_pmode(seldom) = '0' or S_EN = 0 then
                  rdata(0) := r.m_idc(selhart).idelivery;
                else
                  rdata(0) := r.s_idc(selhart).idelivery;
                end if;
              when "001" =>  -- iforce (0x04)
                if r.domain_pmode(seldom) = '0' or S_EN = 0 then
                  rdata(0) := r.m_idc(selhart).iforce;
                else
                  rdata(0) := r.s_idc(selhart).iforce;
                end if;
              when "010" =>  -- ithreshold (0x08)
                if r.domain_pmode(seldom) = '0' or S_EN = 0 then
                  rdata(IPRIOLEN-1 downto 0) := r.m_idc(selhart).ithreshold;
                else
                  rdata(IPRIOLEN-1 downto 0) := r.s_idc(selhart).ithreshold;
                end if;
              when "110" | "111" =>  -- topi (0x18)| claimi (0x1C)
                if r.domain_pmode(seldom) = '0' or S_EN = 0 then  -- Machine mode
                  rdata(16+srcbits-1 downto 16)  := r.m_idc(selhart).topi_id;
                  rdata(IPRIOLEN-1 downto 0) := r.m_idc(selhart).topi_pri;
                  if r.haddr(2) = '1' then --claimi
                    -- clear iforce or the pending bit
                    if unsigned(r.m_idc(selhart).topi_id) = 0 then
                      v.m_idc(selhart).iforce := '0';
                    elsif r.sourcecfg_SM(conv_integer(r.m_idc(selhart).topi_id)) /= level0 and
                          r.sourcecfg_SM(conv_integer(r.m_idc(selhart).topi_id)) /= level1 then
                      v.setip(conv_integer(r.m_idc(selhart).topi_id)) := '0';
                    end if;
                  end if;
                else -- Supervisor mode
                  rdata(16+srcbits-1 downto 16)  := r.s_idc(selhart).topi_id;
                  rdata(IPRIOLEN-1 downto 0) := r.s_idc(selhart).topi_pri;
                  if r.haddr(2) = '1' then --claimi
                    if unsigned(r.s_idc(selhart).topi_id) = 0 then
                      v.s_idc(selhart).iforce := '0';
                    elsif r.sourcecfg_SM(conv_integer(r.s_idc(selhart).topi_id)) /= level0 and
                          r.sourcecfg_SM(conv_integer(r.s_idc(selhart).topi_id)) /= level1 then
                      v.setip(conv_integer(r.s_idc(selhart).topi_id)) := '0';
                    end if;
                  end if;
                end if;
              when others =>
            end case;
          end if;
        end if;
        -- endianness
        if r.domaincfg(seldom).BE = '1' then
          rdata := change_endianness(rdata);
        end if;
      elsif seldom = ndomains then
        -- Write domains hart masks that configure to which hart each domain can forward
        -- the active interrupts
        if sel_dommask < ndomains then
          rdata(ncpu-1 downto 0) := r.active_harts(sel_dommask);
        end if;
      end if;
      v.hrdata := rdata;
    end if;



    -- Write access
    if r.hsel(1) = '1' and r.hwrite = '1' and r.hsize = "010" then -- Transfer size must be 32 bits long
      if seldom < ndomains then
        -- Endianness
        if r.domaincfg(seldom).BE = '1' then
          wdata := change_endianness(wdata);
        end if;
        if struct_off = "0" then -- First 16 KiB registers (non-IDC registers)
          case r.haddr(13 downto 12) is
            when "00" =>
              if r.haddr(11 downto 0) = x"000" then -- domaincfg  (0x0000)
                v.domaincfg(seldom).IE := wdata(8);
                if direct_delivery = 1 then
                  v.domaincfg(seldom).DM := wdata(2);
                end if;
                if endianness = 2 then -- bi-endian system
                  v.domaincfg(seldom).BE := wdata(0); 
                end if;
              elsif selsrc <= nsources then -- sourcecfg[1] to sourcecfg[1024]
                if r.sourcecfg(seldom).implemented(selsrc) = '1' then -- source must be implemented in this domain
                  if wdata(10) = '1' then --D = 1
                    v.sourcecfg(seldom).D(selsrc) := '1';                                                
                    if leaf_doms(seldom) = '1' then -- If it is a leaf domain and D = 1, the whole register is set to 0
                      v.sourcecfg_SM(selsrc) := (others => '0');
                      v.sourcecfg(seldom).D(selsrc) := '0'; 
                    else
                      -- Any write to a sourcecfg register might (or might not) cause the corresponding interrupt-pending
                      -- bit to be set to one if the rectified input value is high (= 1) under the new source mode.
                      v.sourcecfg(seldom).D(selsrc) := '1';                                                
                      if r.sourcecfg(seldom).D(selsrc) = '0' then
                        -- If source i was not delegated to this domain and is then changed (at the parent domain) to become delegated 
                        -- to this domain, sourcecfg[i] remains zero until successfully written with a nonzero value.
                        v.sourcecfg_SM(selsrc) := (others => '0');
                        v.sourcecfg(seldom+1).D(selsrc) := '0';                                                
                      end if;
                    end if;
                    -- If it is the root domain, the child_index field is writable
                    if seldom = 0 and unsigned(wdata(9 downto 0)) <= branches then
                      v.child_index(selsrc) := wdata(branch_bits-1 downto 0);
                    end if;
                  else -- D = 0
                    v.src_inverted(selsrc) := '0';
                    -- A write to a sourcecfg register will not by itself cause a pending bit to be cleared 
                    -- except when the source is made inactive.
                    if wdata(2 downto 0) = inactive then
                      v.setip(selsrc) := '0';
                      v.setie(selsrc) := '0';
                    elsif wdata(2 downto 0) = edge0 or wdata(2 downto 0) = level0 then 
                      v.src_inverted(selsrc) := '1';
                    end if;
                    if wdata(2 downto 0) /= "010" and wdata(2 downto 0) /= "011" then
                      -- WARL register 010 and 011 are not allowed values
                      v.sourcecfg_SM(selsrc) := wdata(2 downto 0);
                    end if;
                    v.sourcecfg(seldom).D(selsrc) := '0'; 
                    -- If source i is changed from inactive to an active mode, target[i] becomes 
                    -- an unspecified valid value
                    if wdata(2 downto 0) /= "000" and wdata(2 downto 0) /= "010" and wdata(2 downto 0) /= "011" and 
                       r.sourcecfg_SM(selsrc) = "000" then
                      first_active_hart := 0;
                      for j in ncpu-1 downto 0 loop
                        if r.active_harts(seldom)(j) = '1' then 
                          first_active_hart := j;
                        end if;
                      end loop;
                      v.target(selsrc).hart_index := conv_std_logic_vector(first_active_hart, ncpubits);
                      v.target(selsrc).guest_index := (others => '0');
                      v.target(selsrc).iprio := conv_std_logic_vector(1, IPRIOLEN);
                      v.target(selsrc).EIID := conv_std_logic_vector(1, eiidbits);
                    end if;
                  end if;
                end if;
              end if;
            when "01" => 
              case r.haddr(11 downto 8) is
                when x"B" => -- addrcfg
                  if seldom = 0 and r.mmsiaddrcfg.L = '0' then -- These registers are accesible only for the root domain and when L=0
                    case r.haddr(7 downto 0) is
                      when x"C0" => -- mmsiaddrcfg   (0x1BC0)
                        v.mmsiaddrcfg.base_ppn(31 downto 0) := wdata;
                      when x"C4" => -- mmsiaddrcfgh  (0x1BC4)
                        v.mmsiaddrcfg.L    := wdata(31);
                        v.mmsiaddrcfg.HHXS := wdata(28 downto 24); 
                        v.mmsiaddrcfg.LHXS := wdata(22 downto 20); 
                        v.mmsiaddrcfg.HHXW := wdata(18 downto 16); 
                        v.mmsiaddrcfg.LHXW := wdata(15 downto 12); 
                        v.mmsiaddrcfg.base_ppn(43 downto 32) := wdata(11 downto 0);
                      when x"C8" => -- smsiaddrcfg   (0x1BC8)
                        if unsigned(r.domain_pmode) /= 0 then -- There is at least one supervisor-level interrupt domain
                          v.smsiaddrcfg.base_ppn(31 downto 0) := wdata;
                        end if;
                      when x"CC" => -- smsiaddrcfgh  (0x1BCC)
                        if unsigned(r.domain_pmode) /= 0 then -- There is at least one supervisor-level interrupt domain
                          v.smsiaddrcfg.LHXS := wdata(22 downto 20);
                          v.smsiaddrcfg.base_ppn(43 downto 32) := wdata(11 downto 0);
                        end if;
                      when others =>
                    end case;
                  end if;
                when x"C" => -- setip
                  if r.haddr(7 downto 0) = x"DC" then -- setipnum (0x1CDC)
                    if unsigned(wdata) <= nsources then
                      setnum := conv_integer(wdata);
                      if r.sourcecfg_SM(setnum) = detached or r.sourcecfg_SM(setnum) = edge0 or r.sourcecfg_SM(setnum) = edge1
                         or  ((r.sourcecfg_SM(setnum) = level0 or r.sourcecfg_SM(setnum) = level1) and r.domaincfg(seldom).DM ='1' and v.src_rectified(setnum) = '1') then
                        v.setip(setnum) := r.setip(setnum) or r.sourcecfg(seldom).active(setnum);
                      end if;
                    end if;
                  else -- setip[0] to setip[31]
                    for i in 1 to nsources loop
                      if i/32 = selsrc_reg then
                        if r.sourcecfg_SM(i) = detached or r.sourcecfg_SM(i) = edge0 or r.sourcecfg_SM(i) = edge1
                           or  ((r.sourcecfg_SM(i) = level0 or r.sourcecfg_SM(i) = level1) and r.domaincfg(seldom).DM ='1' and v.src_rectified(i) = '1') then
                          v.setip(i) := r.setip(i) or (wdata(i mod 32) and r.sourcecfg(seldom).active(i));
                        end if;
                      end if;
                    end loop;
                  end if;
                  v.setip(0) := '0'; -- bit 0 is read-only zero
                when x"D" => -- clrip
                  if r.haddr(7 downto 0) = x"DC" then -- clripnum (0x1DDC)
                    if unsigned(wdata) <= nsources then
                      setnum := conv_integer(wdata);
                      if r.sourcecfg_SM(setnum) = detached or r.sourcecfg_SM(setnum) = edge0 or r.sourcecfg_SM(setnum) = edge1
                         or  ((r.sourcecfg_SM(setnum) = level0 or r.sourcecfg_SM(setnum) = level1) and r.domaincfg(seldom).DM ='1') then
                        v.setip(setnum) := r.setip(setnum) and not(r.sourcecfg(seldom).active(setnum));
                      end if;
                    end if;
                  else -- in_clrip[0] to in_clrip[31]
                    for i in 1 to nsources loop
                      if i/32 = selsrc_reg then
                        if r.sourcecfg_SM(i) = detached or r.sourcecfg_SM(i) = edge0 or r.sourcecfg_SM(i) = edge1
                           or  ((r.sourcecfg_SM(i) = level0 or r.sourcecfg_SM(i) = level1) and r.domaincfg(seldom).DM ='1') then
                          v.setip(i) := r.setip(i) and not(wdata(i mod 32) and r.sourcecfg(seldom).active(i));
                        end if;
                      end if;
                    end loop;
                  end if;
                when x"E" => -- setie
                  if r.haddr(7 downto 0) = x"DC" then -- setienum (0x1EDC)
                    if unsigned(wdata) <= nsources then
                        setnum := conv_integer(wdata);
                        v.setie(setnum) := r.sourcecfg(seldom).active(setnum);
                    end if;
                  else -- setie[0] to setie[31]
                    for i in 1 to nsources loop
                      if i/32 = selsrc_reg then
                        v.setie(i) := r.setie(i) or (wdata(i mod 32) and r.sourcecfg(seldom).active(i));
                      end if;
                    end loop;
                  end if;
                  v.setie(0) := '0'; -- bit 0 is read-only zero
                when x"F" => -- clrie
                  if r.haddr(7 downto 0) = x"DC" then -- clrienum (0x1FDC)
                    if unsigned(wdata) <= nsources then
                      setnum := conv_integer(wdata);
                      v.setie(setnum) := r.setie(setnum) and not(r.sourcecfg(seldom).active(setnum));
                    end if;
                  else -- clrie[0] to clrie[31]
                    for i in 1 to nsources loop
                      if i/32 = selsrc_reg then
                        v.setie(i) := r.setie(i) and not(wdata(i mod 32) and r.sourcecfg(seldom).active(i));
                      end if;
                    end loop;
                  end if;
                when others =>
              end case;
            when "10" =>
              case r.haddr(7 downto 0) is
                when x"00" => -- setipnum_le (0x2000)
                  if endianness /= 1 then -- System is either little-endian or bi-endian
                    -- If domain is configured as big-endian we have to change byte order
                    if r.domaincfg(seldom).BE = '1' then
                      wdata := change_endianness(wdata);
                    end if;
                    if unsigned(wdata) <= nsources then
                        setnum := conv_integer(wdata);
                        v.setip(setnum) := r.setip(setnum) or r.sourcecfg(seldom).active(setnum);
                    end if;
                  end if;
                when x"04" => -- setipnum_be (0x2004)
                  if endianness /= 0 then -- System is either big endian or bi-endian
                    -- If domain is configured as little-endian we have to change byte order
                    if r.domaincfg(seldom).BE = '0' then
                      wdata := change_endianness(wdata);
                    end if;
                    if unsigned(wdata) <= nsources then
                        setnum := conv_integer(wdata);
                        v.setip(setnum) := r.setip(setnum) or r.sourcecfg(seldom).active(setnum);
                    end if;
                  end if;
                when others =>
              end case;
            when others => -- only "11" left
              if r.haddr(11 downto 2) = x"00" & "00" then -- genmsi (0x3000)
                -- When the interrupt domain is configured in direct delivery mode 
                -- (domaincfg.DM = 0), register genmsi is read-only zero
                -- While busy is true, writes are ignored
                if r.domaincfg(seldom).DM = '1' and r.genmsi(seldom).busy = '0' then 
                  -- Write only if the selected domain is configured to deliver the interrupt
                  -- to the especified hart
                  hart_index := conv_integer(wdata(18+ncpubits-1 downto 18));
                  if r.active_harts(seldom)(hart_index) = '1' then
                    v.genmsi(seldom).hart_index := wdata(18+ncpubits-1 downto 18);
                    v.genmsi(seldom).busy       := '1';
                    v.genmsi(seldom).EIID       := wdata(eiidbits-1 downto 0);
                  end if;
                end if;
              elsif selsrc <= nsources then -- target[1] to target[1023]
                if r.sourcecfg(seldom).active(selsrc) = '1' then
                  hart_index := conv_integer(wdata(18+ncpubits-1 downto 18));
                  if r.domaincfg(seldom).DM = '0' then
                    -- Write only if the selected domain is configured to deliver the interrupt
                    -- to the especified hart
                    if r.active_harts(seldom)(hart_index) = '1' then
                      v.target(selsrc).hart_index := wdata(18+ncpubits-1 downto 18);
                    end if;
                    -- A write to a target register sets IPRIO equal to bits (IPRIOLEN − 1):0 of the 32-bit
                    -- value written, unless those bits are all zeros, in which case the priority number is set to 1 instead.
                    if wdata(IPRIOLEN-1 downto 0) = zero32(IPRIOLEN-1 downto 0) then
                      v.target(selsrc).iprio(0) := '1';
                    else
                      v.target(selsrc).iprio := wdata(IPRIOLEN-1 downto 0);
                    end if;
                  else
                    -- Write only if the selected domain is configured to deliver the interrupt
                    -- to the especified hart
                    if r.active_harts(seldom)(hart_index) = '1' then
                      -- Write hart_index for machine-level interrupt domains and
                      -- guest_guest index for supervisor-level interrupt domains
                      v.target(selsrc).hart_index  := wdata(18+ncpubits-1 downto 18);
                      if r.domain_pmode(seldom) = '1' and H_EN = 1 then 
                        v.target(selsrc).guest_index := wdata(12+nvcpubits-1 downto 12);
                      else
                        v.target(selsrc).guest_index := (others => '0');
                      end if;
                    end if;
                    v.target(selsrc).EIID := wdata(eiidbits-1 downto 0);
                  end if;
                end if;
              end if;
          end case;
        elsif direct_delivery = 1 then -- Interrupt delivery control (IDC) structure
          if selhart < ncpu and r.active_harts(seldom)(selhart) = '1' then
            case r.haddr(4 downto 2) is
              when "000" =>  -- idelivery (0x00)
                if r.domain_pmode(seldom) = '0' or S_EN = 0 then
                  v.m_idc(selhart).idelivery := wdata(0);
                else
                  v.s_idc(selhart).idelivery := wdata(0);
                end if;
              when "001" =>  -- iforce (0x04)
                if r.domain_pmode(seldom) = '0' or S_EN = 0 then
                  v.m_idc(selhart).iforce := wdata(0);
                else
                  v.s_idc(selhart).iforce := wdata(0);
                end if;
              when "010" =>  -- ithreshold (0x08)
                if r.domain_pmode(seldom) = '0' or S_EN = 0 then
                  v.m_idc(selhart).ithreshold(IPRIOLEN-1 downto 0) := wdata(IPRIOLEN-1 downto 0);
                else
                  v.s_idc(selhart).ithreshold(IPRIOLEN-1 downto 0) := wdata(IPRIOLEN-1 downto 0);
                end if;
              when others =>
            end case;
          end if;
        end if;
      elsif seldom = ndomains then
        -- Write domains hart masks that configure to which hart each domain can forward
        -- the active interrupts
        if sel_dommask < ndomains then
          v.active_harts(sel_dommask) := wdata(ncpu-1 downto 0);
        end if;
      end if;
    end if;


    -- Error response (only support 32-bit accesses)
    if pipe then
      if r.hsel(0) = '1' then 
        if r.hsize /= "010" then
          v.hready := '0';
          v.hresp  := HRESP_ERROR;
        end if;
      end if;
    else
      if v.hsel(0) = '1' then
        if v.hsize /= "010" then
          v.hready := '0';
          v.hresp  := HRESP_ERROR;
        end if;
      end if;
    end if;
    -- Second error response cycle
    if r.hready = '0' and r.hresp = HRESP_ERROR then
      v.hresp := HRESP_ERROR;
    end if;

    -- Read data
    if pipe then
      hrdata := r.hrdata;
    else
      hrdata := rdata;
      v.hrdata := (others => '0');
    end if;


    -- Signal assignation 

    -- AHB Interface
    ahbso.hready         <= r.hready;
    ahbso.hrdata         <= ahbdrivedata(hrdata);
    ahbso.hresp          <= r.hresp;
    ahbso.hsplit         <= (others => '0');
    ahbso.hirq           <= (others => '0');
    ahbso.hconfig        <= hconfig;
    ahbso.hindex         <= hsindex;


    -- To IMSIC
    meip <= meip_tmp;
    seip <= seip_tmp;


    rin <= v;

  end process;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
      if rstn = '0' then
        r <= RES_T;
      end if;
    end if;
  end process;

 -- pragma translate_off
   assert (H_EN = 1 and GEILEN /= 0) or (H_EN = 0 and GEILEN = 0)
   report "Unsupported APLIC configuration: H_EN and GEILEN generics have incompatible values"
   severity failure;
 -- pragma translate_on

end architecture rtl;
