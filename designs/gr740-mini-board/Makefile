include .config

GRLIB=../..
TOP=gr740_mini_board
BOARD=gr740-mini-board

include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)$(SPEED)$(PACKAGE)$(TEMPERATURE)

GRLIB_LATTICE_RADIANT_PERFORMANCE="9_High-Performance_1.0V"
GRLIB_LATTICE_RADIANT_SIM_DEVICE=lfcpnx 


SYNPOPT="set_option -pipe 0; set_option -retiming 0; set_option -write_apr_constraint 0"

LATTICE_IP=lifcl/pll/pll_125i_50o lifcl/mpcs/serdes_channel_0 lifcl/mpcs/serdes_channel_2 \
		   lifcl/mpcs/serdes_channel_6 lifcl/mpcs/serdes_channel_7 lifcl/sedc/cram_sedc lifcl/osc/osc_cram_sedc_50o 

LATTICE_COM_IP_FOLDER?=$(HOME)/RadiantIPLocal
LATTICE_COM_IP=latticesemi.com_ip_ddr3_mc_1.4.2/lattice_ddr3c

VHDLSYNFILES=config.vhd serdes_wrapper.vhd spacewirerouter_pads.vhd gr740_mini_board.vhd
VHDLSIMFILES= testbench.vhd
SIMTOP=testbench

PDC=gr740_mini_board.pdc
#LDC=gr740_mini_board.ldc
SDCFILE=gr740_mini_board.sdc


BITGEN=$(GRLIB)/boards/$(BOARD)/default.ut
CLEAN=soft-clean
VCOMOPT=-explicit
TECHLIBS=nexus

VSIMOPT= -voptargs="+acc -nowarn 1"
VSIMOPT+= -t 10fs
VSIMOPT+= $(SIMTOP)
VSIMOPT+= -do $(GRLIB)/bin/runvsim.do

#LIBSKIP = actel cern contrib core1553bbc core1553brm core1553brt  corePCIF cypress fmf gr1553 gsi  hynix idt ihp \
    micron microsemi opencores orbita riscv shyloc spansion spfi srio synplify tech  testgrouppolito tmtc wizl \
	work \
	
DIRSKIP = aft ambatest aplic ascs b1553 can canfd clk2x crypto ddrv1 ftaddr gr1553b \
    gr1553bv1 grdmac grfpc grfpc4 grfpc5  grfpcft grfpcv1 grfpu griommu2 grlfpc grlfpc4 \
	grlfpcft grlfpcv1 grlfpu grfpu5 grrm \
	hcan l2c_lite leon2 leon2ft \
	leon4v0 leon5 leon5v0 leon5v0/blockred lram mma nand \
	noelv noelv/subsys pcie plic pwm satcan slink socbridge spacefibre \
	usb ge_1000baseX riscv \

FILESKIP = grcan.vhd adapters/sgmii.vhd\
	#sf2apbslv_wrapper.vhd sf2ficmst_wrapper.vhd sf2ficslv_wrapper.vhd \
	#sf2mddr_wrapper.vhd pfmddr_wrapper.vhd

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/leon3/Makefile


##################  project specific targets ##########################
sim_mem: ../../lib/micron/nandflash/b17a_fortis_nand_model/nand_die_model.v ../../lib/micron/nandflash/b17a_fortis_nand_model/nand_model.v
	make sim
	vlog -sv +define+CLASSU +define+SHORT_RESET ../../lib/micron/nandflash/b17a_fortis_nand_model/nand_die_model.v
	vlog -sv +define+CLASSU +define+SHORT_RESET ../../lib/micron/nandflash/b17a_fortis_nand_model/nand_model.v
