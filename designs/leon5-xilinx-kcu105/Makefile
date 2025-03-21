### GRLIB general setup and extra target to clean software

include .config
GRLIB=../..
CLEAN=soft-clean

###################################################
#DESIGN CONFIGURATION
# Set the AHB data width of the design (supported 128,64 and 32) 
AHB-WIDTH=128

############  GRLIB_CONFIGURATION ########################

ifeq ("$(AHB-WIDTH)","32")
GRLIB_CONFIG=rtl/ahb-32bits/grlib_config_leon5.vhd
else
GRLIB_CONFIG=grlib_config_leon5.vhd
endif

############  Board Setup  ########################

### Xilinx Vivado device and board setup
BOARD=xilinx-kcu105-xcku040
DESIGN=leon5-xilinx-kcu105
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

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
VSIMOPT= -L secureip -L unisims_ver glbl
GRLIB_COMPILE_VIVADO_IP=Y


# Use MIG with AXI interface with width=128 when AXI4 interface is selected
ifeq ($(CONFIG_MIG_7SERIES),y)
VIVADO_MIG_AXI=1
AXI_128=1
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

# Toplevel
VSIMOPT+= $(SIMTOP)

VSIMOPT+= -do $(GRLIB)/bin/runvsim.do

### End of Simulation Options ###

### Synthesize Options ###

VIVADO_IMPL_STRATEGY=Performance_ExplorePostRoutePhysOpt

### End of Synthesize Options ###


### Testbench, design and libraries to compile and not to compile

RTL=$(GRLIB)/designs/$(DESIGN)/rtl

VHDLSYNFILES= rtl/ddr4ram.vhd rtl/axi_mig4_7series.vhd rtl/ahb2axi_mig4_7series.vhd rtl/sgmii_kcu105.vhd \
		config.vhd ahbrom128.vhd ahbrom64.vhd ahbrom.vhd leon5mp.vhd $(MEMTECH) 
VHDLSIMFILES= testbench.vhd 

VERILOGSYNFILES=
VERILOGSIMFILES=$(XILINX_VIVADO)/data/verilog/src/glbl.v

TECHLIBS = unisim
SKIP_SIM_TECHLIBS = 1

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp spw gsi cypress hynix ge_1000baseX \
	spansion secureip usb ddr grdmac mmuconfig atf micron 	esa fmf
DIRSKIP = b1553 pci gr1553b/core pci/pcif leon2 leon2ft leon3 leon3v3 leon4 leon4v0 \
        irqmp grfpc4 grlfpc4 subsys srio idt crypto satcan pci ambatest \
	spacewire ascs slink hssl pwm gr1553b iommu ac97 secureip canfd \
	nand grrm mma lram clk2x

FILESKIP = grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd

OBJCOPY_CMD=sparc-gaisler-elf-objcopy

# For memmap=0
BOPT=
LDFLAGS=

include $(GRLIB)/software/leon5/Makefile
include $(GRLIB)/bin/Makefile


##################  project specific targets ##########################

### Synthesis ###
ifeq ("$(AHB-WIDTH)","32")
MIG_IP= rtl/axi_32/mig.xci
MIG_CDC_IP= rtl/axi_32/mig_cdc.xci
else ifeq ("$(AHB-WIDTH)","64")
MIG_IP= rtl/axi_64/mig.xci
MIG_CDC_IP= rtl/axi_64/mig_cdc.xci
else
MIG_IP= rtl/axi_128/mig.xci
MIG_CDC_IP= rtl/axi_128/mig_cdc.xci
endif


cp-mig-files: scripts
	@echo "!!!!! Overwriting board mig files with local files"
	cp $(MIG_IP)  vivado/mig.xci
	cp $(MIG_CDC_IP) vivado/mig_cdc.xci
	cp rtl/axi_128/axi_pipe.xci vivado/axi_pipe.xci
	cp rtl/sgmii.xci vivado/sgmii.xci
	cp rtl/sem_ultra_0.xci vivado/sem_ultra_0.xci

vivado-launch: cp-mig-files

vivado: cp-mig-files
