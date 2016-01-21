include .config
GRLIB=../..
TOP=leon3mp
ifeq ("$(CONFIG_LEON4)","y")
GRLIB_CONFIG=grlib_config_leon4.vhd
endif
DESIGN=leon3-xilinx-ml605
BOARD=xilinx-ml605-xc6vlx240t
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)$(SPEED)
#UCF=$(GRLIB)/boards/$(BOARD)/$(TOP).ucf
UCF=$(TOP).ucf
UCF_PLANAHEAD=$(TOP)_mig39.ucf
#ISEMAPOPT=-timing
QSF=$(GRLIB)/boards/$(BOARD)/$(TOP).qsf
EFFORT=high
XSTOPT=-uc leon3mp.xcf
SYNPOPT="set_option -pipe 1; set_option -retiming 0; set_option -enable_prepacking 1;\
set_option -write_apr_constraint 0;set_option -resource_sharing 1; set_option -symbolic_fsm_compiler 1"
VHDLOPTSYNFILES= \
	mig_37/user_design/rtl/controller/arb_mux.vhd \
	mig_37/user_design/rtl/controller/arb_row_col.vhd \
	mig_37/user_design/rtl/controller/arb_select.vhd \
	mig_37/user_design/rtl/controller/bank_cntrl.vhd \
	mig_37/user_design/rtl/controller/bank_common.vhd \
	mig_37/user_design/rtl/controller/bank_compare.vhd \
	mig_37/user_design/rtl/controller/bank_mach.vhd \
	mig_37/user_design/rtl/controller/bank_queue.vhd \
	mig_37/user_design/rtl/controller/bank_state.vhd \
	mig_37/user_design/rtl/controller/col_mach.vhd \
	mig_37/user_design/rtl/controller/mc.vhd \
	mig_37/user_design/rtl/controller/rank_cntrl.vhd \
	mig_37/user_design/rtl/controller/rank_common.vhd \
	mig_37/user_design/rtl/controller/rank_mach.vhd \
	mig_37/user_design/rtl/controller/round_robin_arb.vhd \
	mig_37/user_design/rtl/ecc/ecc_buf.vhd \
	mig_37/user_design/rtl/ecc/ecc_dec_fix.vhd \
	mig_37/user_design/rtl/ecc/ecc_gen.vhd \
	mig_37/user_design/rtl/ecc/ecc_merge_enc.vhd \
	mig_37/user_design/rtl/ip_top/clk_ibuf.vhd \
	mig_37/user_design/rtl/ip_top/ddr2_ddr3_chipscope.vhd \
	mig_37/user_design/rtl/ip_top/infrastructure.vhd \
	mig_37/user_design/rtl/ip_top/iodelay_ctrl.vhd \
	mig_37/user_design/rtl/ip_top/mem_intfc.vhd \
	mig_37/user_design/rtl/ip_top/memc_ui_top.vhd \
	mig_37/user_design/rtl/ip_top/mig_37.vhd \
	mig_37/user_design/rtl/phy/circ_buffer.vhd \
	mig_37/user_design/rtl/phy/phy_ck_iob.vhd \
	mig_37/user_design/rtl/phy/phy_clock_io.vhd \
	mig_37/user_design/rtl/phy/phy_control_io.vhd \
	mig_37/user_design/rtl/phy/phy_data_io.vhd \
	mig_37/user_design/rtl/phy/phy_dly_ctrl.vhd \
	mig_37/user_design/rtl/phy/phy_dm_iob.vhd \
	mig_37/user_design/rtl/phy/phy_dq_iob.vhd \
	mig_37/user_design/rtl/phy/phy_dqs_iob.vhd \
	mig_37/user_design/rtl/phy/phy_init.vhd \
	mig_37/user_design/rtl/phy/phy_pd.vhd \
	mig_37/user_design/rtl/phy/phy_pd_top.vhd \
	mig_37/user_design/rtl/phy/phy_rdclk_gen.vhd \
	mig_37/user_design/rtl/phy/phy_rdctrl_sync.vhd \
	mig_37/user_design/rtl/phy/phy_rddata_sync.vhd \
	mig_37/user_design/rtl/phy/phy_rdlvl.vhd \
	mig_37/user_design/rtl/phy/phy_read.vhd \
	mig_37/user_design/rtl/phy/phy_top.vhd \
	mig_37/user_design/rtl/phy/phy_write.vhd \
	mig_37/user_design/rtl/phy/phy_wrlvl.vhd \
	mig_37/user_design/rtl/phy/rd_bitslip.vhd \
	mig_37/user_design/rtl/ui/ui_cmd.vhd \
	mig_37/user_design/rtl/ui/ui_rd_data.vhd \
	mig_37/user_design/rtl/ui/ui_top.vhd \
	mig_37/user_design/rtl/ui/ui_wr_data.vhd \
	pcie/v6_pcie_v1_7/source/*.vhd \
	$(GRLIB)/lib/gaisler/pcie/pcie.vhd

ifeq ("$(CONFIG_PCIEXP_MASTER_TARGET)","y")
  ifeq ("$(CONFIG_LANE_WIDTH1)","y")
  UCF+=pcie_ucf/pcie_master_target_lane1.ucf
  UCF_PLANAHEAD+=pcie_ucf/pcie_master_target_lane1.ucf
  endif
  ifeq ("$(CONFIG_LANE_WIDTH2)","y")
  UCF+=pcie_ucf/pcie_master_target_lane2.ucf
  UCF_PLANAHEAD+=pcie_ucf/pcie_master_target_lane2.ucf
  endif
  ifeq ("$(CONFIG_LANE_WIDTH4)","y")
  UCF+=pcie_ucf/pcie_master_target_lane4.ucf
  UCF_PLANAHEAD+=pcie_ucf/pcie_master_target_lane4.ucf
  endif
  ifeq ("$(CONFIG_LANE_WIDTH8)","y")
  UCF+=pcie_ucf/pcie_master_target_lane8.ucf
  UCF_PLANAHEAD+=pcie_ucf/pcie_master_target_lane8.ucf
  endif
VHDLOPTSYNFILES+=$(GRLIB)/lib/gaisler/pcie/pcie_master_target_virtex.vhd
endif
ifeq ("$(CONFIG_PCIEXP_MASTER_FIFO)","y")
  ifeq ("$(CONFIG_PCIEXP_MASTER_FIFO_DMA)","y")
    ifeq ("$(CONFIG_LANE_WIDTH1)","y")
    UCF+=pcie_ucf/pcie_master_fifo_dma_lane1.ucf
    UCF_PLANAHEAD+=pcie_ucf/pcie_master_fifo_dma_lane1.ucf
    endif
    ifeq ("$(CONFIG_LANE_WIDTH2)","y")
    UCF+=pcie_ucf/pcie_master_fifo_dma_lane2.ucf
    UCF_PLANAHEAD+=pcie_ucf/pcie_master_fifo_dma_lane2.ucf
    endif
    ifeq ("$(CONFIG_LANE_WIDTH4)","y")
    UCF+=pcie_ucf/pcie_master_fifo_dma_lane4.ucf
    UCF_PLANAHEAD+=pcie_ucf/pcie_master_fifo_dma_lane4.ucf
    endif
VHDLOPTSYNFILES+=$(GRLIB)/lib/gaisler/pcie/pcie_master_fifo_virtex.vhd
VHDLOPTSYNFILES+=$(GRLIB)/lib/gaisler/pcie/pciedma.vhd
  endif
  ifneq ("$(CONFIG_PCIEXP_MASTER_FIFO_DMA)","y")
    ifeq ("$(CONFIG_LANE_WIDTH1)","y")
    UCF+=pcie_ucf/pcie_master_fifo_lane1.ucf
    UCF_PLANAHEAD+=pcie_ucf/pcie_master_fifo_lane1.ucf
    endif
    ifeq ("$(CONFIG_LANE_WIDTH2)","y")
    UCF+=pcie_ucf/pcie_master_fifo_lane2.ucf
    UCF_PLANAHEAD+=pcie_ucf/pcie_master_fifo_lane2.ucf
    endif
    ifeq ("$(CONFIG_LANE_WIDTH4)","y")
    UCF+=pcie_ucf/pcie_master_fifo_lane4.ucf
    UCF_PLANAHEAD+=pcie_ucf/pcie_master_fifo_lane4.ucf
    endif
VHDLOPTSYNFILES+=$(GRLIB)/lib/gaisler/pcie/pcie_master_fifo_virtex.vhd
  endif
endif

VERILOGOPTSYNFILES= \
	mig/user_design/rtl/controller/*.v \
	mig/user_design/rtl/ecc/*.v \
	mig/user_design/rtl/ip_top/*.v \
	mig/user_design/rtl/phy/*.v \
	mig/user_design/rtl/phy/*.v \
	mig/user_design/rtl/ui/*.v \
	$$XILINX/verilog/src/glbl.v
VHDLSYNFILES= \
	ahb2mig_ml605.vhd config.vhd ahbrom.vhd \
	svga2ch7301c.vhd gtxclk.vhd leon3mp.vhd

VHDLSIMFILES=testbench.vhd

ifeq ("$(CONFIG_PCIEXP_MASTER_TARGET)","y")
VHDLSIMFILES+=$(GRLIB)/lib/tech/unisim/ise/GTPA1_DUAL.vhd $(GRLIB)/lib/tech/unisim/ise/GTP_DUAL.vhd \
$(GRLIB)/lib/tech/unisim/ise/GTXE1.vhd $(GRLIB)/lib/tech/unisim/ise/GTX_DUAL.vhd \
$(GRLIB)/lib/tech/unisim/ise/PCIE_2_0.vhd $(GRLIB)/lib/tech/unisim/ise/PCIE_A1.vhd
else 
ifeq ("$(CONFIG_PCIEXP_MASTER_FIFO)","y")
VHDLSIMFILES+=$(GRLIB)/lib/tech/unisim/ise/GTPA1_DUAL.vhd $(GRLIB)/lib/tech/unisim/ise/GTP_DUAL.vhd \
$(GRLIB)/lib/tech/unisim/ise/GTXE1.vhd $(GRLIB)/lib/tech/unisim/ise/GTX_DUAL.vhd \
$(GRLIB)/lib/tech/unisim/ise/PCIE_2_0.vhd $(GRLIB)/lib/tech/unisim/ise/PCIE_A1.vhd
endif
endif
SIMTOP=testbench
SDCFILE=default.sdc
BITGEN=$(GRLIB)/boards/$(BOARD)/default.ut
PLANAHEAD_BITGEN=-g DebugBitstream:No -g Binary:no -b -g CRC:Enable -g CclkPin:PullUp -g M0Pin:PullUp -g M1Pin:PullUp -g M2Pin:PullUp -g ProgPin:PullUp -g DonePin:PullUp -g TckPin:PullUp -g TdiPin:PullUp -g TdoPin:PullUp -g TmsPin:PullUp -g UnusedPin:PullDown -g UserID:0xFFFFFFFF -g StartUpClk:CCLK -g DONE_cycle:4 -g GTS_cycle:5 -g GWE_cycle:6 -g LCK_cycle:NoWait -g Security:None -g Persist:No -g ReadBack -g DonePipe:No -g DriveDone:Yes
CLEAN=soft-clean migclean pcieclean
TECHLIBS = xilinxcorelib_ver secureip_ver unisims_ver secureip unisim
VLOGOPT= -O0
VCOMOPT= -explicit -O0 
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT= +access +w -t ps -novopt +notimingchecks -L secureip_ver -L xilinxcorelib_ver -L unisims_ver glbl $(SIMTOP)
else
VSIMOPT= -t ps -novopt +notimingchecks -L secureip_ver -L xilinxcorelib_ver -L unisims_ver glbl $(SIMTOP)
endif

LIBSKIP = core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip ihp usbhc spw gsi cypress hynix \
	spansion
DIRSKIP = b1553 pci/pcif leon2 leon2ft crypto satcan ambatest can \
	usb grusbhc spacewire ascs slink spi hcan \
	leon4v0 l2cache pwm gr1553b iommu ac97
ifeq ("$(CONFIG_LEON4)","")
DIRSKIP+=leon4v0
endif
FILESKIP = grcan.vhd ddr2.v mobile_ddr.v

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/leon3/Makefile

##################  project specific targets ##########################

mig_37 mig:
	cp grlib_mig/mig.* .
	coregen -b mig.xco -p mig.cgp
	patch -p1 < grlib_mig/mig.diff
	patch -p0 < grlib_mig/mig_reset13.diff
mig39:
	cp grlib_mig/mig39.* .
	coregen -b mig39.xco -p mig39.cgp
	patch -p1 < grlib_mig/mig_patch.txt
	patch -p1 < grlib_mig/mig_iodelay_ctrl_patch.txt
	patch -p1 < grlib_mig/mig_infrastructure_patch.txt
	patch -p1 < grlib_mig/mig_ucf_patch.txt
	patch -p0 < grlib_mig/mig_reset14.diff

migclean:
	-rm -rf tmp coregen* mig*

pcie:
	coregen -b pcie/pcie.xco -p pcie
	patch -p0 < pcie.diff

pcieclean:
	-rm -rf pcie/v6_pcie_v1_7* pcie/tmp pcie/coregen.cgc tx.dat rx.dat

.PHONY : pcie pcieclean
