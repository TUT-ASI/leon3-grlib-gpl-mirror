include .config
GRLIB=../..
TOP=leon3mp
BOARD=xilinx-ml510-xc5vfx130t
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)$(SPEED)
UCF=leon3mp.ucf
XSTOPT=-uc leon3mp.xcf
QSF=$(GRLIB)/boards/$(BOARD)/$(TOP).qsf
EFFORT=high
ISEMAPOPT=-m -timing
SYNPOPT="set_option -pipe 1; set_option -retiming 1; set_option -write_apr_constraint 0"
VHDLSYNFILES= config.vhd ahbrom.vhd \
	svga2ch7301c.vhd leon3mp.vhd
VHDLSIMFILES=testbench.vhd

VERILOGSIMFILES = $$XILINX/verilog/src/glbl.v

SIMTOP=testbench
SDCFILE=default.sdc
BITGEN=$(GRLIB)/boards/$(BOARD)/default.ut
CLEAN=soft-clean

include $(GRLIB)/software/leon3/Makefile

VSIMOPT= -gdisas=1 -gDEBUG=0 +nowarnTSCALE +nowarnTFMPC +nowarnPCDPC -t 1ps testbench

VLOGOPT= +define+MODEL_TECH=1

TECHLIBS = xilinxcorelib_ver secureip_ver unisims_ver secureip unisim virtex5
LIBSKIP = core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip ihp usbhc spw micron
DIRSKIP = b1553 pci/pcif leon2 leon2ft crypto satcan can leon3ft \
	grusbhc usb spacewire hcan leon4 leon4v0 l2cache \
	slink ascs pwm gr1553b iommu ambatest atf

FILESKIP = grcan.vhd ahb2mig_series7_ddr2.vhd

include $(GRLIB)/bin/Makefile


##################  project specific targets ##########################
