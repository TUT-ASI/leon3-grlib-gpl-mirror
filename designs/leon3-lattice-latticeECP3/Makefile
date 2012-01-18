include .config
GRLIB=../..
TOP=leon3mp
BOARD=lattice-ecp3-lfe3-35ea
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)$(SPEED)
LPF=$(GRLIB)/boards/$(BOARD)/$(TOP).lpf
PRF=$(GRLIB)/boards/$(BOARD)/$(TOP).prf
EFFORT=high
SYNPOPT="set_option -pipe 0; set_option -retiming 0; set_option -write_apr_constraint 0"
VHDLSYNFILES=config.vhd ahbrom.vhd leon3mp.vhd
VHDLSIMFILES=testbench.vhd
SIMTOP=testbench

#VHDLOPTSYNFILES= \

SDCFILE=default.sdc
BITGEN=$(GRLIB)/boards/$(BOARD)/default.ut
CLEAN=soft-clean
TECHLIBS = secureip

LIBSKIP = core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip ihp gleichmann usbhc spw gsi cypress hynix \
	spansion

DIRSKIP = b1553 pcif leon2 leon2ft crypto satcan pci leon3ft ambatest can \
	usb grusbhc spacewire ata haps coremp7 ascs slink spi hcan \
	leon4 leon4b64 l2cache pwm gr1553b iommu ac97

FILESKIP = grcan.vhd ddr2.v mobile_ddr.v

#GRLIB_CONFIG = grlib_config.vhd

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/leon3/Makefile

##################  project specific targets ##########################

