include .config

GRLIB=../..
TOP=leon3mp
BOARD=lattice-lfcpnx-versa-evn
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)$(SPEED)$(PACKAGE)$(TEMPERATURE)


GRLIB_LATTICE_RADIANT_PERFORMANCE="9_High-Performance_1.0V"
#GRLIB_LATTICE_RADIANT_SYNTHESIS=lse
GRLIB_LATTICE_RADIANT_SIM_DEVICE=lfcpnx




SYNPOPT="set_option -pipe 0; set_option -retiming 0; set_option -write_apr_constraint 0"

VHDLSYNFILES=config.vhd leon3mp.vhd
VHDLSIMFILES=testbench.vhd
SIMTOP=testbench
LATTICE_IP=lifcl/pll/pll_125i_50o

#PDC=$(GRLIB)/boards/$(BOARD)/LIFCL-40-EVN.pdc
PDC=leon3mp.pdc
LDC=leon3mp.ldc
SDCFILE=leon3mp.sdc

BITGEN=$(GRLIB)/boards/$(BOARD)/default.ut
CLEAN=soft-clean
VCOMOPT=-explicit
TECHLIBS=nexus

VSIMOPT= -voptargs="+acc -nowarn 1"
VSIMOPT+= -t 10fs
VSIMOPT+= $(SIMTOP)
VSIMOPT+= -do $(GRLIB)/bin/runvsim.do

LIBSKIP = core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip hynix cypress ihp gsi fmf spansion spw hssl \
	eth micron esa
DIRSKIP = b1553 pci/pcif leon2 leon2ft crypto satcan pci leon3ft ambatest ddr \
	leon4v0 l2cache/v2 gr1553b iommu ascs slink pwm \
	ge_1000baseX canfd \
	leon5v0 leon5v0/blockred grfpu5 noelv noelv/subsys riscv \
	ftaddr hcan greth spacewire spacefibre usb nand \
	grdmac grdmac2 grscrub plic grfpc5 l2c_lite \
	grrm socbridge axi mma can lram
FILESKIP = grcan.vhd adapters/sgmii.vhd \
	sf2apbslv_wrapper.vhd sf2ficmst_wrapper.vhd sf2ficslv_wrapper.vhd \
	sf2mddr_wrapper.vhd pfmddr_wrapper.vhd

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/leon3/Makefile


##################  project specific targets ##########################
