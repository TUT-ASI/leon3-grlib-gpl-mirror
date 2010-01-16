GRLIB=../..
TOP=leon3mp
BOARD=gr-pci-xc2v
#BOARD=gr-cpci-xc2v
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)$(SPEED)
UCF=$(GRLIB)/boards/$(BOARD)/$(TOP).ucf
QSF=$(GRLIB)/boards/$(BOARD)/$(TOP).qsf
EFFORT=std
XSTOPT=
VHDLSYNFILES=
VHDLSIMFILES=apbuart_tp.vhd simuart.vhd apbuart_tb.vhd
SIMTOP=apbuart_tb
SDCFILE=$(GRLIB)/boards/$(BOARD)/default.sdc
BITGEN=$(GRLIB)/boards/$(BOARD)/default.ut
CLEAN=local-clean
FILESKIP=i2cmst.vhd
LIBSKIP=memctrl fpu leon3 leon3ft can hcan ambatest net pci pcif jtag \
b1553 greth usb ddr crypto ata satcan slink ascs haps coremp7 esa hynix \
micron openchip tmtc cypress gsi spansion fmf gleichmann gr1553 corePCIF \
core1553brm core1553brt core1553bbc ihp opencores eth spw spacewire
TECHLIBS= unisim axcelerator

include $(GRLIB)/bin/Makefile


##################  project specific targets ##########################

VPATH=$(GRLIB)/software/leon3

include $(GRLIB)/software/leon3/Makefile

local-clean:
	-rm -rf *.o *.exe *.a

compile_simprim:
	vlib simprim
	vcom -quiet -work SIMPRIM  $(XILINX)/vhdl/src/simprims/simprim_Vpackage.vhd
	vcom -quiet -work SIMPRIM $(XILINX)/vhdl/src/simprims/simprim_Vcomponents.vhd
	vcom -quiet -work SIMPRIM $(XILINX)/vhdl/src/simprims/simprim_VITAL.vhd


compile_unisim:
	vlib UNISIM
	vcom -quiet -work UNISIM $(XILINX)/vhdl/src/unisims/unisim_VCOMP.vhd
	vcom -quiet -work UNISIM $(XILINX)/vhdl/src/unisims/unisim_VPKG.vhd
	vcom -quiet -work UNISIM $(XILINX)/vhdl/src/unisims/unisim_VITAL.vhd

compile_xilinxcorelib:
	vlib xilinxcorelib
	cat $XILINX/vhdl/src/XilinxCoreLib/vhdl_analyze_order


compile_logiblox:
	vlib logiblox
	vcom -quiet -work LOGIBLOX $(XILINX)/vhdl/src/logiblox/mvlutil.vhd
	vcom -quiet -work LOGIBLOX $(XILINX)/vhdl/src/logiblox/mvlarith.vhd
	vcom -quiet -work LOGIBLOX $(XILINX)/vhdl/src/logiblox/logiblox.vhd

complib:
	export PATH=/usr/local/xilinx62/bin/lin/:$(PATH); compxlib -s mti_se -f virtex -l vhdl -o netlist/
