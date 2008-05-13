GRLIB=../..
TOP=leon3mp
BOARD=avnet-eval-xc4v
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)$(SPEED)
#UCF=$(GRLIB)/boards/$(BOARD)/$(TOP).ucf
UCF=leon3mp.ucf
XSTOPT= -uc leon3mp.xcf
SYNPOPT="set_option -pipe 0; set_option -retiming 0; set_option -write_apr_constraint 0"
QSF=$(GRLIB)/boards/$(BOARD)/$(TOP).qsf
EFFORT=high
VHDLSYNFILES=config.vhd leon3mp.vhd
VHDLSIMFILES=delay_wire.vhd testbench.vhd
SIMTOP=testbench
#SDCFILE=$(GRLIB)/boards/$(BOARD)/default.sdc
SDCFILE=default.sdc
BITGEN=$(GRLIB)/boards/$(BOARD)/default.ut
CLEAN=soft-clean

TECHLIBS = unisim inferred

LIBSKIP = core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip hynix ihp gleichmann tsmc90 dw02 spw usbhc eth opencores \
	esa fmf spansion gsi
DIRSKIP = b1553 pcif leon2 leon2ft crypto satcan pci leon3ft can usb \
					fpu/grfpu fpu/grfpc fpu/grlfpc leon3 uart jtag greth spacewire ata grusbhc \
					slink asac haps coremp7
FILESKIP = grcan.vhd simple_spi_top.v i2cmst.vhd 

include $(GRLIB)/software/leon3/Makefile
XLDFLAGS=-L./ lib3tests.a -Ttext=0x40000000

include $(GRLIB)/bin/Makefile


##################  project specific targets ##########################

