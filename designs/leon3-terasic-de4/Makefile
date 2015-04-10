include .config
GRLIB=../..
GRLIB_CONFIG=grlib_config.vhd
TOP=leon3mp
BOARD=terasic-de4
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)$(SPEED)
#UCF=$(GRLIB)/boards/$(BOARD)/$(TOP).ucf
UCF=leon3mp.ucf
#UCF=leon3mp_gbit_usb.ucf
QSF=$(GRLIB)/boards/$(BOARD)/$(TOP).qsf
EFFORT=high
XSTOPT=
ISEMAPOPT=-timing
VHDLSYNFILES=ddr2if.vhd config.vhd leon3mp.vhd
VHDLSIMFILES=ddr2sim.vhd testbench.vhd
SIMTOP=testbench
SDCFILE=default.sdc
#SDCFILE=$(GRLIB)/boards/$(BOARD)/default.sdc
BITGEN=$(GRLIB)/boards/$(BOARD)/default.ut
CLEAN=soft-clean
SYNPOPT="set_option -pipe 1; set_option -retiming 1; set_option -write_apr_constraint 0"
#VSIMOPT=-gdisas=1

QSF_APPEND=qsf_append.qsf
QSF_NEXT=qsf_pin_assign.tcl

TECHLIBS = altera altera_mf stratixiii
LIBSKIP = core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip hynix cypress ihp fmf spansion gsi
DIRSKIP = b1553 pci/pcif leon2 leon2ft crypto satcan \
	slink ascs leon3ft leon4 leon4v0 \
	spacewire usb pwm gr1553b iommu pci hcan 

FILESKIP = grcan.vhd

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/leon3/Makefile

##################  project specific targets ##########################

qwiz:
	@cp $(GRLIB)/boards/$(BOARD)/ddr2ctrl.vhd .
	@if [ ! -d ./ddr2ctrl/ ]; then \
		qmegawiz -silent ddr2ctrl.vhd ; \
	else \
		echo "ddr2ctrl core already compiled"; \
	fi ;

localclean:
	@rm -rf ddr2ctrl.vhd ddr2ctrl ddr2ctrl_sim ddr2ctrl_example_design ddr2ctrl.[bcpqs]* ddr2ctrl_sim.f

