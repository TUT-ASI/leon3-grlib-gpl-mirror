### GRLIB general setup and extra target to clean software

############  RISC-V NOEL-V Core  ########################
BASE_DIR ?= .
COM_DIR ?= $(BASE_DIR)/rtl/common
CFG_DIR ?= $(BASE_DIR)
CFG_LOCAL_DIR ?= $(CFG_DIR)/cfg
TB_DIR ?= $(BASE_DIR)/tb
include $(CFG_DIR)/.config
GRLIB_CONFIG ?= $(CFG_DIR)/grlib_config.vhd
GRLIB = $(BASE_DIR)/../..

############  Project  ########################

### Simulation Options ###
# Design Top Level
TOP=noelvmp

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
GRLIB_SIMULATOR ?= ModelSim

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
VSIMOPT= -gdisas=0

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc" +notimingchecks
else
VSIMOPT+=-novopt +notimingchecks
endif

# Simulation scripts
VSIMOPT+= -do $(GRLIB)/bin/runvsim.do
ASIMDO = run -all

# Toplevel
VSIMOPT+= $(SIMTOP)

### End of Simulation Options ###

### Testbench, design and libraries to compile and not to compile

RTL=$(GRLIB)/designs/$(DESIGN)/rtl

VHDLSYNFILES  = 
VHDLSYNFILES += $(CFG_DIR)/config.vhd
VHDLSYNFILES += $(CFG_LOCAL_DIR)/config_local.vhd
VHDLSYNFILES += $(COM_DIR)/rev.vhd
VHDLSYNFILES += $(COM_DIR)/cfgmap.vhd
VHDLSYNFILES += $(COM_DIR)/noelvcore.vhd
VHDLSYNFILES += $(COM_DIR)/ahbrom.vhd
VHDLSYNFILES += $(BASE_DIR)/rtl/noelvmp.vhd 
VHDLSIMFILES  = $(TB_DIR)/testbench.vhd 

TECHLIBS = inferred

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp spw gsi cypress hynix ge_1000baseX \
	spansion secureip usb ddr grdmac mmuconfig fmf esa micron spfi
DIRSKIP = b1553 pci gr1553b/core pci/pcif leon2 leon2ft leon5 leon5v0 srio idt crypto satcan pci ambatest \
	spacewire ascs slink irqmp grdmac grrm nand\
	pwm gr1553b iommu ac97 secureip mmuiface clk2x canfd leon4v0 spacefibre

FILESKIP = grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd iu4.vhd

CLEAN = soft-clean

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/noelv/systest/Makefile

##################  project specific targets ##########################

### Simulation ###
#### Synthesis ###
