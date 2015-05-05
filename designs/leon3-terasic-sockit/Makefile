GRLIB=../..
TOP=leon3mp
BOARD=terasic-sockit
ALTCABLE="CV SoCKit"
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)$(SPEED)
QSF=$(GRLIB)/boards/$(BOARD)/$(TOP).qsf
EFFORT=high
XSTOPT=
SYNPOPT="set_option -pipe 0; set_option -retiming 0; set_option -write_apr_constraint 0"
VHDLSYNFILES=config.vhd ahbrom.vhd ahb2axi.vhd axi2ahb.vhd ddr3if.vhd leon3mp.vhd
VHDLSIMFILES=testbench.vhd ddr3sim.vhd
SIMTOP=testbench
SDCFILE=$(GRLIB)/boards/$(BOARD)/default.sdc
BITGEN=$(GRLIB)/boards/$(BOARD)/default.ut
CLEAN=soft-clean
LDFLAGS=-qnoambapp

QSF_APPEND=qsf_append.qsf
QSF_NEXT=qsf_pin_assign.tcl

TECHLIBS = altera altera_mf
LIBSKIP = core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip ihp hynix cypress
DIRSKIP = b1553 pci/pcif leon2 leon2ft crypto satcan pci leon3ft ambatest can \
	usbhc usb spacewire grusbhc \
	slink ascs hcan leon4 leon4v0
FILESKIP = grcan.vhd

include $(GRLIB)/software/leon3/Makefile
include $(GRLIB)/bin/Makefile


##################  project specific targets ##########################


qwiz:

	@cp $(GRLIB)/boards/$(BOARD)/ddr3controller.vhd .
	@if [ ! -d ./ddr3controller/ ]; then \
		qmegawiz -silent ddr3controller.vhd ; \
	else \
		echo "ddr3controller core already compiled"; \
	fi ;

localclean:
	@rm -rf ddr3controller ddr3controller_sim ddr3controller_example_design ddr3controller.[bcpqsv]* ddr3controller_sim.f 
