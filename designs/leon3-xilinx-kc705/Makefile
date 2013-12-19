
### GRLIB general setup and extra target to clean software
include .config
GRLIB=../..
CLEAN=soft-clean

### Xilinx Vivado device and board setup
BOARD=xilinx-kc705-xc7k325t
DESIGN=leon3-xilinx-kc705
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)$(PACKAGE)-$(SPEED)
XDC=$(GRLIB)/boards/$(BOARD)/$(BOARD).xdc

### Simulation Options ###
# Design Top Level
TOP=leon3mp

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
GRLIB_SIMULATOR=ModelSim

# Options used during compilation
VCOMOPT=-explicit -O0
VLOGOPT= +define+x1Gb +define+sg125 +define+x8 -suppress 2902

# GRLIB Options
VSIMOPT= -gdisas=1

# GRETH options
ifeq ($(CONFIG_GRETH_ENABLE),y)
VSIMOPT+= -gEXAMPLE_SIMULATION=1 -L secureip_ver -L xilinxcorelib_ver -L unisims_ver 
endif

# - MIG -
#
# DEBUG - Print debug information from external DDR3 memory (1/0) 
#
ifeq ($(CONFIG_MIG_SERIES7),y)
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= -do "do riviera_preload_ddr3_dimm.do; run -all"
else
VSIMOPT+= -do "do preload_ddr3_dimm.do; run -all" 
endif
VSIMOPT+= -t fs -novopt -gDEBUG=0
VSIMOPT+= -L secureip_ver -L xilinxcorelib_ver -L unisims_ver glbl
GRLIB_XIL_Vivado_sim_verilog_define=x1Gb sg125 x8
ifndef CONFIG_MIG_SERIES_7_MODEL
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false 
else
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true -t ps
endif
endif

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc" +notimingchecks
else
VSIMOPT+=-novopt +notimingchecks
endif

# Toplevel
VSIMOPT+= $(SIMTOP)

### End of Simulation Options ###

### Testbench, design and libraries to compile and not to compile

VHDLSYNFILES= config.vhd ahbrom.vhd leon3mp.vhd ddr_dummy.vhd
VHDLSIMFILES=testbench.vhd

TECHLIBS = secureip unisim 
EXTRA_SOFT = gen_hex_dim

LIBSKIP = pci pci/pcif core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip ihp spw gsi cypress hynix \
	spansion leon4 leon4v0 secureip
DIRSKIP = b1553 pci pci/pcif leon2 leon2ft crypto satcan pci ambatest \
	spacewire ascs slink \
	leon4 leon4v0 l2cache pwm gr1553b iommu ac97 secureip
FILESKIP = grcan.vhd ddr2.v mobile_ddr.v

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
	@echo
	@echo " ================================================================"
	@echo "         Quick start guide for simulation of systest.c"
	@echo
	@echo "  1. Setup search paths for Xilinx, GCC and Modelsim "
	@echo "  2. make vsim"
	@echo "  3. make mig_series7"
	@echo "  4. make soft"
	@echo "  5. make vsim-launch"
	@echo
	@echo " Please note that this quick start guide will compile and simulate"
	@echo " a preconfigured version of the leon3 processor system."
	@echo " For customizing the leon3 susbsystem run make 'xconfig'"
	@echo " ================================================================"
	@echo
