### GRLIB general setup and extra target to clean software

include .config
GRLIB=../..
CLEAN=soft-clean

############  Leon Core  ########################

GRLIB_CONFIG=grlib_config_leon5.vhd

############  Board Setup  ########################

### Xilinx Vivado device and board setup
BOARD=xilinx-vcu128-xcvu37p
DESIGN=leon5-xilinx-vcu128
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)-$(SPEED)
XDC=$(GRLIB)/boards/$(BOARD)/$(BOARD).xdc

############  Project  ########################

### Simulation Options ###
# Design Top Level
TOP=leon5mp

# Simulation top level
SIMTOP=testbench

# Uncomment to change to specify your simulator (default is Modelsim)
#GRLIB_SIMULATOR=ALDEC
#MIG_SIM=y

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
VSIMOPT= -L secureip -L unisims_ver  
GRLIB_COMPILE_VIVADO_IP=Y


# Use MIG with AXI interface with width=128 when AXI4 interface is selected
ifeq ($(CONFIG_MIG_7SERIES),y)
VIVADO_MIG_AXI=1
endif

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc -nowarn 1" +notimingchecks
else
VSIMOPT+= -voptargs="+acc -nowarn 1" +notimingchecks -64
endif

GRLIB_XILINX_SOURCE_MGMT_MODE=DisplayOnly

# Remove collision check in UNSIM library
VSIMOPT+= -GSIM_COLLISION_CHECK="GENERATE_X_ONLY"
ASIMOPT+= -GSIM_COLLISION_CHECK="GENERATE_X_ONLY"

ifeq ($(MIG_SIM),y)
VSIMOPT+= work.glbl -L xpm -L microblaze_v11_0_4 -L xil_defaultlib -L lib_cdc_v1_0_2 -L proc_sys_reset_v5_0_13 -L lmb_v10_v3_0_11 -L lmb_bram_if_cntlr_v4_0_19 -L blk_mem_gen_v8_4_4 -L iomodule_v3_1_6 -L axi_infrastructure_v1_1_0 -L fifo_generator_v13_2_5 -L axi_clock_converter_v2_1_21
endif


# Toplevel
VSIMOPT+= $(SIMTOP)

VSIMOPT+= -do $(GRLIB)/bin/runvsim.do

### End of Simulation Options ###

### Synthesize Options ###

VIVADO_IMPL_STRATEGY=Performance_ExplorePostRoutePhysOpt

### End of Synthesize Options ###


### Testbench, design and libraries to compile and not to compile

RTL=$(GRLIB)/designs/$(DESIGN)/rtl

VHDLSYNFILES=  rtl/ahb2axi_mig4_7series.vhd rtl/sgmii_vcu128.vhd \
		config.vhd ahbrom128.vhd leon5mp.vhd $(MEMTECH) 
VHDLSIMFILES= testbench.vhd 

VERILOGSYNFILES=

TECHLIBS = unisim
SKIP_SIM_TECHLIBS = 1

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp gsi cypress hynix ge_1000baseX spfi spw wizl\
	spansion secureip usb ddr grdmac mmuconfig atf micron esa fmf
DIRSKIP = b1553 pci gr1553b/core pci/pcif leon2 leon2ft srio idt crypto satcan pci ambatest \
	ascs slink pwm gr1553b iommu ac97 secureip canfd nandfctrl2 nand \
	grrm mma lram hssl spacewire memctrl hcan can grdmac2 ftaddr

FILESKIP = grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd

OBJCOPY_CMD=sparc-gaisler-elf-objcopy

# For memmap=0
BOPT=
LDFLAGS=

include $(GRLIB)/software/leon5/Makefile
include $(GRLIB)/bin/Makefile


##################  project specific targets ##########################

### Synthesis ###
modify-comp: cp-xci-files
	tclsh modify_vivado.tcl

cp-xci-files: scripts
	@echo "!!!!! Overwriting board IP files with local files"
	cp -f xilinx_ip/axi_512/mig.xci ./vivado/mig.xci
	cp -f xilinx_ip/axi_512/mig_cdc.xci ./vivado/mig_cdc.xci
	cp -f xilinx_ip/axi_512/axi_pipe.xci ./vivado/axi_pipe.xci
	cp -f xilinx_ip/axi_512/axi_dw_conv.xci ./vivado/
	cp -f xilinx_ip/sgmii/sgmii.xci ./vivado/sgmii.xci
	sed -i '/sem_ultra/d' ./vivado/leon5mp_vivado.tcl

vivado-launch: modify-comp

vivado: modify-comp

comp_mig: ip_7series_generate map_xilinx_7series_lib sim
	vsim -c -do compile_mig.do
