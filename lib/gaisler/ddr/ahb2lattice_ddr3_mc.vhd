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
-- Entity:      ahb2lattice_ddr3_mc
-- File:        ahb2lattice_ddr3_mc.vhd
-- Author:      Henrik Gingsjö - Frontgrade Gaisler
-- Description: Lattice DDR3 memory controller with AHB interface
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;

library gaisler;
use gaisler.misc.rstgen;

library techmap;
use techmap.gencomp.all;

entity ahb2lattice_ddr3_mc is
  generic (
    hindex : integer := 0;
    haddr  : integer := 0;
    hmask  : integer := 16#F80#;
    addr_w : integer := 26;
    core_data_w : integer := 128);
  port(
    rstn : in std_logic;

    ahbsi : in  ahb_slv_in_type;
    ahbso : out ahb_slv_out_type;

    -- signals to ddr3_mc
    rst_n_o : out std_logic;
    mem_rst_n_o : out std_logic;
    init_start_o : out std_logic;
    cmd_o : out std_logic_vector(3 downto 0);
    addr_o : out std_logic_vector(addr_w - 1 downto 0);
    cmd_burst_cnt_o : out std_logic_vector(4 downto 0);
    cmd_valid_o : out std_logic;
    write_data_o : out std_logic_vector(core_data_w - 1 downto 0);
    data_mask_o : out std_logic_vector(core_data_w/8 - 1 downto 0);

    -- signals from ddr3_mc
    cmd_rdy_i         : in std_logic;
    datain_rdy_i      : in std_logic;
    init_done_i       : in std_logic;
    rt_err_i          : in std_logic;
    wl_err_i          : in std_logic;
    read_data_i       : in std_logic_vector(core_data_w - 1 downto 0);
    read_data_valid_i : in std_logic;
    sclk_i            : in std_logic;
    clocking_good_i   : in std_logic;

    -- Debug signals
    init_done : out std_logic;
    init_err  : out std_logic
    );
end ahb2lattice_ddr3_mc;

architecture rtl of ahb2lattice_ddr3_mc is

  constant data_mask_w : integer := core_data_w/8;

  signal cmdclk, cmdclk_lock : std_logic;
  signal dirdy : std_logic;
  signal do : std_logic_vector(core_data_w - 1 downto 0);
  signal dov : std_logic; -- data out valid
  signal initdone, rterr, wlerr : std_logic; -- status output

  signal cmd : std_logic_vector(3 downto 0);
  signal addr : std_logic_vector(addr_w - 1 downto 0);
  signal cmd_brst_cnt : std_logic_vector(4 downto 0);
  signal cmdval : std_logic;
  signal di : std_logic_vector(core_data_w - 1 downto 0); -- data in
  signal dim : std_logic_vector(data_mask_w - 1 downto 0); -- data in byte mask

  signal cmdrdy : std_logic; -- command in ready

  type ahbddr3_reg_type is record
    haddr : std_logic_vector(31 downto 0);
    hsel : std_logic;
    hwrite : std_logic;
    hburst : std_logic_vector(2 downto 0);
    hsize : std_logic_vector(2 downto 0);

    cmd : std_logic_vector(3 downto 0);
    addr : std_logic_vector(addr_w - 1 downto 0);
    cmd_brst_cnt : std_logic_vector(4 downto 0);
    cmdval : std_logic;

    dirdy : std_logic; -- delayed one clock cycle

    init_flag   : std_logic;
    init_start  : std_logic;
    init_done   : std_logic;
    wlerr : std_logic; -- write-levelling error
    rterr : std_logic; -- read-training error
  end record;

  signal r, rin : ahbddr3_reg_type;

begin

  init_done <= r.init_done;
  init_err <= r.wlerr or r.rterr; --r.cnt(27);

  -- signals to ddr3_mc
  rst_n_o <= rstn;
  mem_rst_n_o <= '1';
  init_start_o <= r.init_start;
  cmd_o <= cmd;
  addr_o <= addr(addr_w-1 downto 0); -- convert byte address to word address
  cmd_burst_cnt_o <= cmd_brst_cnt;
  cmd_valid_o <= cmdval;
  write_data_o <= di;
  data_mask_o <= dim;

  -- signals from ddr3_mc
  cmdrdy <= cmd_rdy_i;
  dirdy <= datain_rdy_i;
  initdone <= init_done_i;
  rterr <= rt_err_i;
  wlerr <= wl_err_i;
  do <= read_data_i;
  dov <= read_data_valid_i;
  cmdclk <= sclk_i;
  cmdclk_lock <= clocking_good_i;

  -- AHB-based DDR3 controller...
  ddrasync : process(r, ahbsi, rstn, initdone, rterr, wlerr, cmdrdy, dirdy, do, dov)
    -- Valid command codes from Table 2.5
    constant CMD_READ   : std_logic_vector(3 downto 0) := "0001";
    constant CMD_WRITE  : std_logic_vector(3 downto 0) := "0010";
    constant CMD_READA  : std_logic_vector(3 downto 0) := "0011";
    constant CMD_WRITEA : std_logic_vector(3 downto 0) := "0100";
    constant CMD_PDWNEN : std_logic_vector(3 downto 0) := "0101";
    constant CMD_LMR    : std_logic_vector(3 downto 0) := "0110";
    constant CMD_SREFEN : std_logic_vector(3 downto 0) := "1000";
    constant CMD_SREFEX : std_logic_vector(3 downto 0) := "1001";
    constant CMD_PDWNEX : std_logic_vector(3 downto 0) := "1011";
    constant CMD_ZQLONG : std_logic_vector(3 downto 0) := "1100";
    constant CMD_ZQSHRT : std_logic_vector(3 downto 0) := "1101";
    variable v : ahbddr3_reg_type;
    variable vhready : std_logic;
    constant w_amba : integer := 32;
    variable vhrdata : std_logic_vector(w_amba - 1 downto 0);-- need to change based on amba data bus
    variable vdi : std_logic_vector(core_data_w - 1 downto 0); -- data in
    variable vdim : std_logic_vector(data_mask_w - 1 downto 0); -- data in byte mask
    constant mask_addr_w : integer := log2(core_data_w) - 3; -- it would be log2(core_data_w/8)
    constant dslices : integer := core_data_w / w_amba;--need to change 32 to the width of the amba (data) bus

    --Return a vector of four bits indicating which byte lanes in a (up-to)
    --128-bit word are addressed given the provided haddr/hsize combination.
    function compute_byte_mask(
      size : std_logic_vector(2 downto 0);
      addr : std_logic_vector(mask_addr_w - 1 downto 0);
      endianess : std_logic) return std_logic_vector is
      variable bytemask : std_logic_vector(data_mask_w - 1 downto 0) := (others => '1');
      variable var_addr : std_logic_vector(mask_addr_w - 1 downto 0);
      variable index : integer := 0;
    begin
      if endianess ='0' then -- big-endian
        var_addr := not addr;
      else -- little-endiane
        var_addr := addr;
      end if;
      case size is
        when "000" => bytemask(conv_integer(var_addr)) := '0'; -- byte access
        when "001" => var_addr(0) := '0'; bytemask(1 + conv_integer(var_addr) downto conv_integer(var_addr)) := "00"; --half-word
        when "010" => var_addr(1 downto 0) := "00"; bytemask(3 + conv_integer(var_addr) downto conv_integer(var_addr)) := "0000"; --word
        when "011" => var_addr(2 downto 0) := "000"; bytemask(7 + conv_integer(var_addr) downto conv_integer(var_addr)) := "00000000"; --double-word
        when others => bytemask := (others => '1'); -- not a sub-word access
      end case;
      return bytemask;
    end function;

    function select_ahb_data(
      addr : std_logic_vector(log2(core_data_w/8)-1 downto 0);
      data : std_logic_vector(core_data_w - 1 downto 0))
      return std_logic_vector is
      variable index : integer := 0;
    begin
      if AHBDW >= core_data_w then
        return data(core_data_w-1 downto 0);
      else
        index := conv_integer(addr(addr'left downto log2(AHBDW/8)));
        return data(index*AHBDW+AHBDW-1 downto index*AHBDW);
      end if;
    end function;

    --Based on haddr lowest bits select the right byte/half-/double-/word from
    --the whole data bus coming from the lattice memory controller.
    function compute_out_data(
      size  : std_logic_vector(2 downto 0);
      addr  : std_logic_vector(mask_addr_w - 1 downto 0);
      data  : std_logic_vector(core_data_w - 1 downto 0);
      endianess : std_logic) return std_logic_vector is
      variable data_out : std_logic_vector(w_amba - 1 downto 0);
      -- need 3 more bits because of the removal we did in its definition
      variable var_addr : std_logic_vector(mask_addr_w - 1 downto 0) := (others => '0');
      variable haddr : std_logic_vector(31 downto 0) := (others => '0');
    begin
      if endianess ='0' then -- big-endian
        var_addr(mask_addr_w - 1 downto 0) := not addr;
        -- var_addr(1 downto 0) := "11";
      else -- little-endian
        var_addr(mask_addr_w - 1 downto 0) := addr;
        -- var_addr(1 downto 0) := "11";
      end if;
      haddr(mask_addr_w-1 downto 0) := var_addr;

      if CORE_ACDM = 0 then
        -- Need to select the right 32/64/128/...-bit sub-block and duplicate it
        return ahbselectdatabe(ahbdrivedata(select_ahb_data(var_addr, data)), haddr(4 downto 2), size);
      else
        -- Can just pass through the data
        return ahbdrivedata(select_ahb_data(var_addr, data));
      end if;
    end function;

  begin
    v := r;
    vhready := '1';

    v.hsize := ahbsi.hsize;

    v.cmd_brst_cnt := "00001"; -- constant
    v.hburst := ahbsi.hburst;

    -- Data sent on the AHB data phase
    vdi_loop: for i in 1 to dslices loop
      vdi(i*w_amba - 1 downto (i-1)*w_amba) := ahbsi.hwdata;
    end loop vdi_loop;

    vdim := compute_byte_mask(r.hsize, r.haddr(mask_addr_w - 1 downto 0), ahbsi.endian);
    vhrdata := compute_out_data(r.hsize, r.haddr(mask_addr_w - 1 downto 0), do, ahbsi.endian);

    -- if r.haddr(3 downto 2) = "00" then
    --   vdim := x"0fff";
    --   vhrdata := do(127 downto 96);
    -- elsif r.haddr(3 downto 2) = "01" then
    --   vdim := x"f0ff";
    --   vhrdata := do(95 downto 64);
    -- elsif r.haddr(3 downto 2) = "10" then
    --   vdim := x"ff0f";
    --   vhrdata := do(63 downto 32);
    -- else
    --   vdim := x"fff0";
    --   vhrdata := do(31 downto 0);
    -- end if;

    v.dirdy := dirdy;

    v.init_flag := '1';
    if r.init_flag = '0' then
      v.init_start := '1';
    end if;
    if initdone = '1' then
      v.rterr := rterr;
      v.wlerr := wlerr;
      -- Deassert initialization once operation completes
      v.init_start := '0';
      v.init_done := '1';
    end if;

    if r.hsel = '1' then
      -- AHB data phase and we are selected
      vhready := '0';
      --v.cnt := r.cnt + 1;
      if (r.hwrite and r.dirdy) = '1' then
        vhready := '1';
      end if;
      if ((not r.hwrite) and dov) = '1' then
        vhready := '1';
      end if;
      --if andv(r.cnt) = '1' then
      --  vhready := '1';
      --end if;
      v.hsel := not vhready;
    end if;

    -- Command acknowledge
    if cmdrdy = '1' then
      v.cmdval := '0';
    end if;

    if (ahbsi.hready and ahbsi.hsel(hindex) and ahbsi.htrans(1)) = '1' then
      -- AHB address phase and we are selected
      v.hsel := '1';
      v.hwrite := ahbsi.hwrite;
      v.haddr := ahbsi.haddr;
      --v.cnt := (others => '0');

      --if r.prev_haddr(addr_w-1 downto 4) /= v.haddr(31 downto 4) then
      v.cmdval := '1';
      --else
      --  v.
      --end if;
      -- Command sent on the AHB address phase
      if ahbsi.hwrite = '0' then
        v.cmd := CMD_READA;
      else
        v.cmd := CMD_WRITEA;
      end if;
     v.addr := ahbsi.haddr(addr_w - 1 downto 3) & "000";
    end if;

    -- Handle reset
    if rstn = '0' then
      v.init_flag := '0';
      v.init_start := '0';
      v.init_done := '0';
      v.wlerr := '0';
      v.rterr := '0';
      v.hsel := '0';
      v.cmdval := '0';
    end if;

    -- Drive output signals
    rin <= v;

    cmd <= r.cmd;
    cmd_brst_cnt <= r.cmd_brst_cnt;
    cmdval <= r.cmdval;
    addr <= r.addr;
    di <= vdi;
    dim <= vdim;

    ahbso.hready <= vhready;
    ahbso.hresp <= HRESP_OKAY;
    ahbso.hrdata <= ahbdrivedata(vhrdata);
  end process;

  ahbso.hsplit <= (others => '0');
  ahbso.hirq <= (others => '0');
  ahbso.hindex <= hindex;
  ahbso.hconfig <=  (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_LATTICE_DDR3, 0, 0, 0),
    4 => ahb_membar(haddr, '1', '1', hmask),
    others => zero32);

  ddrsync : process(cmdclk)
  begin
    if rising_edge(cmdclk) then
      r <= rin;
    end if;
  end process;

end rtl;
