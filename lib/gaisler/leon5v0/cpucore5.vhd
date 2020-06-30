------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2020, Cobham Gaisler
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
-----------------------------------------------------------------------------
-- Entity:      cpucore5
-- File:        cpucore5.vhd
-- Author:      Magnus Hjorth, Cobham Gaisler
-- Description: LEON5 single processor core (pipeline and cache)
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
library gaisler;
use gaisler.leon5int.all;
use gaisler.arith.all;

entity cpucore5 is
  generic (
    hindex  : integer;
    fabtech : integer;
    memtech : integer;
    cached  : integer;
    wbmask  : integer;
    busw    : integer;
    cmemconf: integer;
    rfconf  : integer;
    fpuconf : integer;
    mulimpl : integer;
    rstaddr : integer;
    disas   : integer
    );
  port (
    clk   : in  std_ulogic;
    rstn  : in  std_ulogic;
    ahbi  : in  ahb_mst_in_type;
    ahbo  : out ahb_mst_out_type;
    ahbsi : in  ahb_slv_in_type;
    ahbso : in  ahb_slv_out_vector;
    irqi  : in  l5_irq_in_type;
    irqo  : out l5_irq_out_type;
    dbgi  : in  l5_debug_in_type;
    dbgo  : out l5_debug_out_type;
    tpo   : out trace_port_out_type;
    fpuo  : in  grfpu5_out_type;
    fpui  : out grfpu5_in_type
    );
end;

architecture hier of cpucore5 is

  constant MEMTECH_MOD : integer := memtech mod 65536;
  constant MEMTECH_VEC : std_logic_vector(31 downto 0) := conv_std_logic_vector(memtech, 32);
  constant IURF_INFER : integer := conv_integer(MEMTECH_VEC(17));
  constant FPRF_INFER : integer := conv_integer(MEMTECH_VEC(18));

  constant mulimpl_iu : integer := mulimpl mod 8;
  constant mulimpl_fpu: integer := (mulimpl/8) mod 8;

  constant nwindows : integer := 8;
  constant iways    : integer := 4;
  constant iwaysize : integer := 4;
  constant ilinesize: integer := 8;
  constant iidxwidth: integer := (log2(iwaysize)+10) - (log2(ilinesize)+2);
  constant itagwidth: integer := 32-(log2(iwaysize)+10)+1;
  constant dways    : integer := 4;
  constant dwaysize : integer := 4;
  constant dlinesize: integer := 8;
  constant didxwidth: integer := (log2(dwaysize)+10) - (log2(dlinesize)+2);
  constant dtagconf : integer := cmemconf mod 4;
  constant dusebw   : integer := (cmemconf / 4) mod 2;
  constant dtagwidth: integer := 32-(log2(dwaysize)+10)+1;
  constant v8       : integer := 16#32# + 4*mulimpl_iu;
  constant scantest : integer := 0;      -- fixme

  constant cdataw   : integer := 64;

  constant g0addr: integer := NWINDOWS*8;

  constant iudisas       : integer := boolean'pos(disas>0);

  constant IRFBITS  : integer range 6 to 10 := log2(NWINDOWS+1) + 4 - 1;
  constant IREGNUM  : integer := (NWINDOWS * 16 + 8)/2;

  signal ici        : icache_in_type5;
  signal ico        : icache_out_type5;
  signal dci        : dcache_in_type5;
  signal dco        : dcache_out_type5;
  signal rfi        : iregfile_in_type5;
  signal rfo        : iregfile_out_type5;
  signal muli       : mul32_in_type;
  signal mulo       : mul32_out_type;
  signal divi       : div32_in_type;
  signal divo       : div32_out_type;
  signal crami      : cram_in_type5;
  signal cramo      : cram_out_type5;
  signal fpco       : fpc5_out_type;
  signal fpci       : fpc5_in_type;
  signal fpc_mosi   : l5_intreg_mosi_type;
  signal xfpui      : grfpu5_in_type;
  signal xfpuo      : grfpu5_out_type;
  signal fprfi      : fpu_regfile_in_type;
  signal fprfo      : fpu_regfile_out_type;
  signal xdbgo      : l5_debug_out_type;
  signal fpc_retire : std_logic;
  signal fpc_retid  : std_logic_vector(4 downto 0);
  signal c2c_mosi   : l5_intreg_mosi_type;

begin

  ----------------------------------------------------------------------------
  -- Integer unit
  ----------------------------------------------------------------------------
  iu0 : iu5
    generic map (
      nwin        => nwindows,
      iways       => iways,
      dways       => dways,
      mulimpl     => mulimpl_iu,
      cp          => 0,
      nwp         => 2,
      pclow       => 0,
      index       => hindex,
      disas       => iudisas,
      rstaddr     => rstaddr,
      fabtech     => fabtech,
      scantest    => scantest,
      memtech     => memtech_mod
      )
    port map (
      clk         => clk,
      rstn        => rstn,
      holdn       => dco.hold,
      ici         => ici,
      ico         => ico,
      dci         => dci,
      dco         => dco,
      rfi         => rfi,
      rfo         => rfo,
      irqi        => irqi,
      irqo        => irqo,
      dbgi        => dbgi,
      dbgo        => xdbgo,
      muli        => muli,
      mulo        => mulo,
      divi        => divi,
      divo        => divo,
      fpu5o       => fpco,
      fpu5i       => fpci,
      tpo         => tpo,
      fpc_retire  => fpc_retire,
      fpc_rfwen   => fprfi.wen,
      fpc_rfwdata => fprfi.wdata,
      fpc_retid   => fpc_retid,
      sclk        => clk,
      testen      => ahbsi.testen,
      testrst     => ahbsi.testrst
      );

  -- multiply and divide units
  mul0 : mul32 generic map (fabtech, v8/16, (v8 mod 4)/2, 0, (v8 mod 16)/4, scantest)
    port map (rstn, clk, dco.hold, muli, mulo, ahbsi.testen, ahbsi.testrst);
  div0 : div32 generic map (scantest)
    port map (rstn, clk, dco.hold, divi, divo, ahbsi.testen, ahbsi.testrst);

  -- Merge dbgo with c2c output from cache controller
  dbgo <= (
    cpustate   => xdbgo.cpustate,
    miso       => xdbgo.miso,
    idle       => xdbgo.idle,
    wakeup_req => xdbgo.wakeup_req,
    c2c_mosi   => c2c_mosi
    );

  ----------------------------------------------------------------------------
  -- Cache controller and MMU
  ----------------------------------------------------------------------------
  cc0: cctrl5
    generic map (
      hindex     => hindex,
      iways      => iways,
      ilinesize  => ilinesize,
      iwaysize   => iwaysize,
      dways      => dways,
      dlinesize  => dlinesize,
      dwaysize   => dwaysize,
      dtagconf   => dtagconf,
      dusebw     => dusebw,
      itlbnum    => 24,
      dtlbnum    => 24,
      cached     => cached,
      wbmask     => wbmask,
      busw       => busw,
      cdataw     => cdataw,
      tlbrepl    => 4
      )
    port map (
      rst      => rstn,
      clk      => clk,
      ici      => ici,
      ico      => ico,
      dci      => dci,
      dco      => dco,
      ahbi     => ahbi,
      ahbo     => ahbo,
      ahbsi    => ahbsi,
      ahbso    => ahbso,
      crami    => crami,
      cramo    => cramo,
      fpuholdn => '1',
      hclk     => clk,
      sclk     => clk,
      hclken   => '1',
      fpc_mosi => fpc_mosi,
      fpc_miso => fpco.miso,
      c2c_mosi => c2c_mosi,
      c2c_miso => dbgi.c2c_miso,
      freeze   => dbgi.freeze,
      bootword => dbgi.boot_word,
      smpflush => dbgi.smpflush
      );

  ----------------------------------------------------------------------------
  -- IU register file
  ----------------------------------------------------------------------------
  ramrf: if (rfconf mod 16)=0 generate
    iurf0: regfile5_ram
      generic map (
        tech    => MEMTECH_MOD*(1-IURF_INFER),
        abits   => IRFBITS,
        dbits   => 64,
        wrfst   => 0,
        numregs => IREGNUM,
        g0addr  => g0addr,
        rfconf  => rfconf,
        testen  => scantest
        )
      port map(
        clk    => clk,
        rstn   => rstn,
        rdhold => rfi.rdhold,
        waddr1 => rfi.waddr1(IRFBITS-1 downto 0),
        wdata1 => rfi.wdata1,
        we1    => rfi.we1,
        waddr2 => rfi.waddr2(IRFBITS-1 downto 0),
        wdata2 => rfi.wdata2,
        we2    => rfi.we2,
        raddr1 => rfi.raddr1(IRFBITS-1 downto 0),
        re1    => rfi.re1,
        rdata1 => rfo.rdata1,
        raddr2 => rfi.raddr2(IRFBITS-1 downto 0),
        re2    => rfi.re2,
        rdata2 => rfo.rdata2,
        raddr3 => rfi.raddr3(IRFBITS-1 downto 0),
        re3    => rfi.re3,
        rdata3 => rfo.rdata3,
        raddr4 => rfi.raddr4(IRFBITS-1 downto 0),
        re4    => rfi.re4,
        rdata4 => rfo.rdata4,
        testin => ahbi.testin
        );
  end generate;

  dffrf: if rfconf=1 generate
    iurf0: regfile5_dff
      generic map (
        abits   => IRFBITS,
        dbits   => 64,
        wrfst   => 0,
        numregs => IREGNUM,
        g0addr  => g0addr,
        rfconf  => rfconf
        )
      port map(
        clk    => clk,
        rstn   => rstn,
        rdhold => rfi.rdhold,
        waddr1 => rfi.waddr1(IRFBITS-1 downto 0),
        wdata1 => rfi.wdata1,
        we1    => rfi.we1,
        waddr2 => rfi.waddr2(IRFBITS-1 downto 0),
        wdata2 => rfi.wdata2,
        we2    => rfi.we2,
        raddr1 => rfi.raddr1(IRFBITS-1 downto 0),
        re1    => rfi.re1,
        rdata1 => rfo.rdata1,
        raddr2 => rfi.raddr2(IRFBITS-1 downto 0),
        re2    => rfi.re2,
        rdata2 => rfo.rdata2,
        raddr3 => rfi.raddr3(IRFBITS-1 downto 0),
        re3    => rfi.re3,
        rdata3 => rfo.rdata3,
        raddr4 => rfi.raddr4(IRFBITS-1 downto 0),
        re4    => rfi.re4,
        rdata4 => rfo.rdata4
        );
  end generate;


  ----------------------------------------------------------------------------
  -- Level 1 cache memories
  ----------------------------------------------------------------------------
  cmem1 : cachemem5
    generic map (
      tech      => MEMTECH_MOD,
      iways     => iways,
      ilinesize => ilinesize,
      iidxwidth => iidxwidth,
      itagwidth => itagwidth,
      dways     => dways,
      dlinesize => dlinesize,
      didxwidth => didxwidth,
      dtagwidth => dtagwidth,
      dtagconf  => dtagconf,
      dusebw    => dusebw,
      testen    => scantest
      )
    port map (
      rstn   => rstn,
      clk    => clk,
      sclk   => clk,
      crami  => crami,
      cramo  => cramo,
      testin => ahbi.testin
      );

  -----------------------------------------------------------------------------
  -- FPC, with or without FPU included
  -----------------------------------------------------------------------------

  nfpugen: if fpuconf=0 generate
    -- nanofpu, all-in-one FPC+FPU+regfile
    nfpu0: nanofpu
      port map (
        clk           => clk,
        rstn          => rstn,
        ready_flop    => fpco.ready_flop,
        ready_ld      => fpco.ready_ld,
        ready_st      => fpco.ready_st,
        trapon_flop   => fpco.trapon_flop,
        trapon_ldst   => fpco.trapon_ldst,
        trapon_stdfq  => fpco.trapon_stdfq,
        issue_cmd     => fpci.issue_cmd,
        issue_ldstreg => fpci.issue_ldstreg,
        issue_ldstdp  => fpci.issue_ldstdp,
        issue_op3_0   => fpci.issue_op3_0,
        issue_flop    => fpci.issue_flop,
        issue_rd      => fpci.issue_rd,
        issue_rs1     => fpci.issue_rs1,
        issue_rs2     => fpci.issue_rs2,
        issue_dfqdata => fpci.issue_dfqdata,
        issue_id      => fpco.issue_id,
        commit        => fpci.commit,
        commitid      => fpci.commitid,
        lddata        => fpci.lddata,
        stdata        => fpco.stdata,
        unissue       => fpci.unissue,
        unissue_sid   => fpci.unissue_sid,
        spstore_pend  => fpci.spstore_pend,
        spstore_done  => fpci.spstore_done,
        fccready      => fpco.fccready,
        fcc           => fpco.fcc,
        fpcidle       => fpco.fpcidle,
        mosi_accen    => fpc_mosi.accen,
        mosi_addr     => fpc_mosi.addr(5 downto 0),
        mosi_accwr    => fpc_mosi.accwr,
        mosi_wrdata   => fpc_mosi.wrdata,
        miso_accrdy   => fpco.miso.accrdy,
        miso_rddata   => fpco.miso.rddata,
        dbgfsr        => fpco.dbgfsr
        );
    fpui <= grfpu5_in_none;
  end generate;

  fpc5gen: if fpuconf=1 generate
    -- GRFPC5 with private FPU
    fpc5: grfpc5
      port map (
        clk           => clk,
        rstn          => rstn,
        ready_flop    => fpco.ready_flop,
        ready_ld      => fpco.ready_ld,
        ready_st      => fpco.ready_st,
        trapon_flop   => fpco.trapon_flop,
        trapon_ldst   => fpco.trapon_ldst,
        trapon_stdfq  => fpco.trapon_stdfq,
        issue_cmd     => fpci.issue_cmd,
        issue_ldstreg => fpci.issue_ldstreg,
        issue_ldstdp  => fpci.issue_ldstdp,
        issue_op3_0   => fpci.issue_op3_0,
        issue_flop    => fpci.issue_flop,
        issue_rd      => fpci.issue_rd,
        issue_rs1     => fpci.issue_rs1,
        issue_rs2     => fpci.issue_rs2,
        issue_dfqdata => fpci.issue_dfqdata,
        issue_id      => fpco.issue_id,
        commit        => fpci.commit,
        commitid      => fpci.commitid,
        lddata        => fpci.lddata,
        stdata        => fpco.stdata,
        unissue       => fpci.unissue,
        unissue_sid   => fpci.unissue_sid,
        spstore_pend  => fpci.spstore_pend,
        spstore_done  => fpci.spstore_done,
        fccready      => fpco.fccready,
        fcc           => fpco.fcc,
        fpcidle       => fpco.fpcidle,
        fpu_start     => xfpui.start,
        fpu_inmode    => xfpui.inmode,
        fpu_outmode   => xfpui.outmode,
        fpu_flop      => xfpui.flop,
        fpu_op1       => xfpui.op1,
        fpu_op2       => xfpui.op2,
        fpu_opid      => xfpui.opid,
        fpu_rndmode   => xfpui.rndmode,
        fpu_res       => xfpuo.res,
        fpu_exc       => xfpuo.exc,
        fpu_allow     => xfpuo.allow,
        fpu_rdy       => xfpuo.rdy,
        fpu_idout     => xfpuo.idout,
        fpu_cmprdy    => xfpuo.cmprdy,
        fpu_cmpidout  => xfpuo.cmpidout,
        fpu_cmpcc     => xfpuo.cmpcc,
        fpu_cmpnv     => xfpuo.cmpnv,
        rf_raddr1     => fprfi.raddr1,
        rf_ren1       => fprfi.ren1,
        rf_rdata1     => fprfo.rdata1,
        rf_raddr2     => fprfi.raddr2,
        rf_ren2       => fprfi.ren2,
        rf_rdata2     => fprfo.rdata2,
        rf_raddr3     => fprfi.raddr3,
        rf_ren3       => fprfi.ren3,
        rf_rdata3     => fprfo.rdata3,
        rf_waddr      => fprfi.waddr,
        rf_wen        => fprfi.wen,
        rf_wdata      => fprfi.wdata,
        mosi_accen    => fpc_mosi.accen,
        mosi_addr     => fpc_mosi.addr(5 downto 0),
        mosi_accwr    => fpc_mosi.accwr,
        mosi_wrdata   => fpc_mosi.wrdata,
        miso_accrdy   => fpco.miso.accrdy,
        miso_rddata   => fpco.miso.rddata,
        retire        => fpc_retire,
        retire_id     => fpc_retid,
        dbgfsr        => fpco.dbgfsr
        );

    fprf0: regfile_fpu
      port map (
        clk       => clk,
        rstn      => rstn,
        rf_raddr1 => fprfi.raddr1,
        rf_ren1   => fprfi.ren1,
        rf_rdata1 => fprfo.rdata1,
        rf_raddr2 => fprfi.raddr2,
        rf_ren2   => fprfi.ren2,
        rf_rdata2 => fprfo.rdata2,
        rf_raddr3 => fprfi.raddr3,
        rf_ren3   => fprfi.ren3,
        rf_rdata3 => fprfo.rdata3,
        rf_waddr => fprfi.waddr,
        rf_wen   => fprfi.wen,
        rf_wdata => fprfi.wdata
        );

    fpu5: grfpu5
      generic map (
        mul      => mulimpl_fpu,
        tech     => fabtech,
        scantest => 0
        )
      port map (
        clk      => clk,
        reset    => rstn,
        start    => xfpui.start,
        inmode   => xfpui.inmode,
        outmode  => xfpui.outmode,
        flop     => xfpui.flop,
        op1      => xfpui.op1,
        op2      => xfpui.op2,
        opid     => xfpui.opid,
        flush    => '0',
        flushid  => "000000",
        rndmode  => xfpui.rndmode,
        res      => xfpuo.res,
        exc      => xfpuo.exc,
        allow    => xfpuo.allow,
        rdy      => xfpuo.rdy,
        idout    => xfpuo.idout,
        cmprdy   => xfpuo.cmprdy,
        cmpidout => xfpuo.cmpidout,
        cmpcc    => xfpuo.cmpcc,
        cmpnv    => xfpuo.cmpnv
        );

    fpui <= grfpu5_in_none;
  end generate;

  extfpu: if fpuconf > 1 generate
    -- GRFPC5 with external FPU
    fpc5: grfpc5
      port map (
        clk           => clk,
        rstn          => rstn,
        ready_flop    => fpco.ready_flop,
        ready_ld      => fpco.ready_ld,
        ready_st      => fpco.ready_st,
        trapon_flop   => fpco.trapon_flop,
        trapon_ldst   => fpco.trapon_ldst,
        trapon_stdfq  => fpco.trapon_stdfq,
        issue_cmd     => fpci.issue_cmd,
        issue_ldstreg => fpci.issue_ldstreg,
        issue_ldstdp  => fpci.issue_ldstdp,
        issue_op3_0   => fpci.issue_op3_0,
        issue_flop    => fpci.issue_flop,
        issue_rd      => fpci.issue_rd,
        issue_rs1     => fpci.issue_rs1,
        issue_rs2     => fpci.issue_rs2,
        issue_dfqdata => fpci.issue_dfqdata,
        issue_id      => fpco.issue_id,
        commit        => fpci.commit,
        commitid      => fpci.commitid,
        lddata        => fpci.lddata,
        stdata        => fpco.stdata,
        unissue       => fpci.unissue,
        unissue_sid   => fpci.unissue_sid,
        spstore_pend  => fpci.spstore_pend,
        spstore_done  => fpci.spstore_done,
        fccready      => fpco.fccready,
        fcc           => fpco.fcc,
        fpcidle       => fpco.fpcidle,
        fpu_start     => xfpui.start,
        fpu_inmode    => xfpui.inmode,
        fpu_outmode   => xfpui.outmode,
        fpu_flop      => xfpui.flop,
        fpu_op1       => xfpui.op1,
        fpu_op2       => xfpui.op2,
        fpu_opid      => xfpui.opid,
        fpu_rndmode   => xfpui.rndmode,
        fpu_res       => xfpuo.res,
        fpu_exc       => xfpuo.exc,
        fpu_allow     => xfpuo.allow,
        fpu_rdy       => xfpuo.rdy,
        fpu_idout     => xfpuo.idout,
        fpu_cmprdy    => xfpuo.cmprdy,
        fpu_cmpidout  => xfpuo.cmpidout,
        fpu_cmpcc     => xfpuo.cmpcc,
        fpu_cmpnv     => xfpuo.cmpnv,
        rf_raddr1     => fprfi.raddr1,
        rf_ren1       => fprfi.ren1,
        rf_rdata1     => fprfo.rdata1,
        rf_raddr2     => fprfi.raddr2,
        rf_ren2       => fprfi.ren2,
        rf_rdata2     => fprfo.rdata2,
        rf_raddr3     => fprfi.raddr3,
        rf_ren3       => fprfi.ren3,
        rf_rdata3     => fprfo.rdata3,
        rf_waddr      => fprfi.waddr,
        rf_wen        => fprfi.wen,
        rf_wdata      => fprfi.wdata,
        mosi_accen    => fpc_mosi.accen,
        mosi_addr     => fpc_mosi.addr(5 downto 0),
        mosi_accwr    => fpc_mosi.accwr,
        mosi_wrdata   => fpc_mosi.wrdata,
        miso_accrdy   => fpco.miso.accrdy,
        miso_rddata   => fpco.miso.rddata,
        retire        => fpc_retire,
        retire_id     => fpc_retid,
        dbgfsr        => fpco.dbgfsr
        );

    fprf0: regfile_fpu
      port map (
        clk       => clk,
        rstn      => rstn,
        rf_raddr1 => fprfi.raddr1,
        rf_ren1   => fprfi.ren1,
        rf_rdata1 => fprfo.rdata1,
        rf_raddr2 => fprfi.raddr2,
        rf_ren2   => fprfi.ren2,
        rf_rdata2 => fprfo.rdata2,
        rf_raddr3 => fprfi.raddr3,
        rf_ren3   => fprfi.ren3,
        rf_rdata3 => fprfo.rdata3,
        rf_waddr => fprfi.waddr,
        rf_wen   => fprfi.wen,
        rf_wdata => fprfi.wdata
        );

    fpui <= xfpui;
    xfpuo <= fpuo;
  end generate;


end;
