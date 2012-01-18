include .config

GRLIB=../..
TOP=leon3mp
BOARD=gr-xc6s
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)$(SPEED)
#UCF=$(GRLIB)/boards/$(BOARD)/$(TOP).ucf
UCF=leon3mp.ucf
ifeq ("$(CONFIG_SPW_ENABLE)","y")
UCF+=spacewire.ucf
endif
ifeq ("$(CONFIG_GRUSBHC_ENABLE)","y")
UCF+=usb.ucf
endif
ifeq ("$(CONFIG_GRUSBDC_ENABLE)","y")
UCF+=usb.ucf
endif
ifeq ("$(CONFIG_GRUSB_DCL)","y")
UCF+=usb.ucf
endif
QSF=$(GRLIB)/boards/$(BOARD)/$(TOP).qsf
EFFORT=high
ISEMAPOPT=-timing
XSTOPT=
SYNPOPT="set_option -maxfan 100; set_option -pipe 1; set_option -retiming 1; set_option -write_apr_constraint 0"
VHDLOPTSYNFILES= mig37/mig_37/user_design/rtl/iodrp_controller.vhd \
	mig37/mig_37/user_design/rtl/iodrp_mcb_controller.vhd \
	mig37/mig_37/user_design/rtl/mcb_raw_wrapper.vhd \
	mig37/mig_37/user_design/rtl/mcb_soft_calibration.vhd \
	mig37/mig_37/user_design/rtl/mcb_soft_calibration_top.vhd \
	mig37/mig_37/user_design/rtl/memc3_infrastructure.vhd \
	mig37/mig_37/user_design/rtl/memc3_wrapper.vhd \
	mig37/mig_37/user_design/rtl/mig_37.vhd
VHDLSYNFILES= \
	config.vhd rgmii.vhd svga2ch7301c.vhd ahbrom.vhd \
	ahb2mig_grxc6s_2p.vhd vga_clkgen.vhd leon3mp.vhd
VHDLSIMFILES=testbench.vhd
SIMTOP=testbench
#SDCFILE=$(GRLIB)/boards/$(BOARD)/default.sdc
SDCFILE=default.sdc
BITGEN=$(GRLIB)/boards/$(BOARD)/default.ut
CLEAN=soft-clean
VCOMOPT=-explicit
TECHLIBS = secureip unisim 

LIBSKIP = core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip cypress ihp gleichmann gsi fmf spansion micron
DIRSKIP = b1553 pcif leon2 leon2ft crypto satcan pci ambatest ddr \
	leon4 leon4b64 l2cache gr1553b iommu haps ascs slink coremp7 pwm \
	ac97 hcan
FILEADD = MCB.vhd
FILESKIP = grcan.vhd

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/leon3/Makefile


##################  project specific targets ##########################

mig:
	coregen -b mig37/mig.xco -p mig37
	patch -p0 < mig.diff

migclean:
	-rm -rf mig37/mig_37* mig37/tmp

