
### GRLIB general setup and extra target to clean software
include .config
GRLIB=../..
CLEAN=soft-clean

### Xilinx Vivado device and board setup
BOARD=xilinx-vc707-xc7vx485t
DESIGN=leon3-xilinx-vc707
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)$(PACKAGE)-$(SPEED)
XDC=$(GRLIB)/boards/$(BOARD)/$(BOARD).xdc

### Simulation Options ###
# Design Top Level
TOP=leon3mp

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
#GRLIB_SIMULATOR=ModelSim

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
#VSIMOPT= -gdisas=1

# GRETH options
ifeq ($(CONFIG_GRETH_ENABLE),y)
VSIMOPT+= -L gig_ethernet_pcs_pma_v14_0 -L secureip_ver -L xilinxcorelib_ver -L unisims_ver 
endif

# - MIG -
ifeq ($(CONFIG_MIG_SERIES7),y)
VSIMOPT+= -t fs -novopt
VSIMOPT+= -L secureip_ver -L xilinxcorelib_ver -L unisims_ver glbl
ifndef CONFIG_MIG_SERIES_7_MODEL
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false -gSIM_BYPASS_INIT_CAL=FAST -gSIMULATION=TRUE
else
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true -t ps
endif
endif

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc" +notimingchecks
else
VSIMOPT+= -novopt +notimingchecks
endif

# Run simulation in batch mode
#VSIMOPT+= -c

# Simulation scripts
VSIMOPT+= -do "run -all"

# Toplevel
VSIMOPT+= $(SIMTOP)

### End of Simulation Options ###

### Testbench, design and libraries to compile and not to compile

VHDLSYNFILES= config.vhd ahbram_sim.vhd ahbrom.vhd leon3mp.vhd ddr_dummy.vhd sgmii_vc707.vhd
VHDLSIMFILES=testbench.vhd

TECHLIBS = secureip unisim

LIBSKIP = pci pci/pcif core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip ihp spw gsi cypress hynix \
	spansion leon4 leon4v0 secureip
DIRSKIP = b1553 pci pci/pcif leon2 leon2ft crypto satcan pci ambatest \
	spacewire ascs slink \
	leon4 leon4v0 l2cache pwm gr1553b iommu ac97 secureip
FILESKIP = grcan.vhd ddr2.v mobile_ddr.v sgmii.vhd

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/leon3/Makefile

##################  project specific targets ##########################

all: help-local

help-local: help
	@echo
	@echo " design specific targets:"
	@echo " (Only needed to generate and compile IPs for Xilinx Series7)"
	@echo
	@echo " make compile_xilinx_verilog_lib   : compile xilinx verilog library"
	@echo " make clean_xilinx_verilog_lib     : remove xilinx verilog library"
	@echo " make mig_series7                  : create xilinx memory controller using coregen."
	@echo " make sgmii_series7                : create SGMII interface using coregen."
	@echo
	@echo " ================================================================"
	@echo "         Quick start guide for simulation of systest.c"
	@echo
	@echo "  1. Setup search paths for Xilinx, GCC and Modelsim "
	@echo "  2. make vsim"
	@echo "  3. make mig_series7"
	@echo "  4. make sgmii_series7"
	@echo "  5. make soft"
	@echo "  6. make vsim-launch"
	@echo
	@echo " Please note that this quick start guide will compile and simulate"
	@echo " a preconfigured version of the leon3 processor system."
	@echo " For customizing the leon3 susbsystem run make 'xconfig'"
	@echo " ================================================================"
	@echo
