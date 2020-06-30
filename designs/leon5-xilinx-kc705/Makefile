### GRLIB general setup and extra target to clean software
include .config
GRLIB=../..
CLEAN=soft-clean

GRLIB_CONFIG=grlib_config_leon5.vhd

### Xilinx Vivado device and board setup
BOARD=xilinx-kc705-xc7k325t
DESIGN=leon5-xilinx-kc705
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)$(PACKAGE)-$(SPEED)
XDC=$(GRLIB)/boards/$(BOARD)/$(BOARD).xdc

### Simulation Options ###
# Design Top Level
TOP=leon5mp

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
#GRLIB_SIMULATOR=ModelSim
#GRLIB_SIMULATOR=ALDEC

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
VSIMOPT=

# GRETH options
ifeq ($(CONFIG_GRETH_ENABLE),y)
VSIMOPT+= -L secureip -L unisims_ver -L unisim 
endif

VIVADO_MIG_AXI=1
AXI_64=1

#AXI_128=1
#GRLIB_XILINX_SOURCE_MGMT_MODE=DisplayOnly



# - MIG -
ifeq ($(CONFIG_MIG_7SERIES),y)
VSIMOPT+= -t fs -voptargs="+acc -nowarn 1" 
VSIMOPT+= -L secureip -L unisims_ver -L unisim glbl
ifndef CONFIG_MIG_7SERIES_MODEL
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false -gSIM_BYPASS_INIT_CAL=FAST -gSIMULATION=TRUE -gEXAMPLE_SIMULATION=1
ASIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false -gSIM_BYPASS_INIT_CAL=FAST -gSIMULATION=TRUE -gEXAMPLE_SIMULATION=1
else
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true -t ps -gEXAMPLE_SIMULATION=1
ASIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true -t ps -gEXAMPLE_SIMULATION=1
endif
endif

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc -nowarn 1" +notimingchecks
else
VSIMOPT+=-voptargs="+acc -nowarn 1" +notimingchecks
endif

# Run simulation in batch mode
#VSIMOPT+= -c

# Remove collision check in UNSIM library
VSIMOPT+= -GSIM_COLLISION_CHECK="GENERATE_X_ONLY"
ASIMOPT+= -GSIM_COLLISION_CHECK="GENERATE_X_ONLY"

# Simulation scripts
VSIMOPT+= -do $(GRLIB)/bin/runvsim.do
ASIMDO = run -all

# Toplevel
VSIMOPT+= $(SIMTOP)

### End of Simulation Options ###

### Synthesize Options ###

VIVADO_IMPL_STRATEGY=Performance_ExplorePostRoutePhysOpt

### End of Synthesize Options ###

### Testbench, design and libraries to compile and not to compile

VHDLSYNFILES= config.vhd ahbrom.vhd leon5mp.vhd ddr_dummy.vhd
VHDLSIMFILES=testbench.vhd

TECHLIBS = unisim
SKIP_SIM_TECHLIBS = 1

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp spw gsi cypress hynix ftaddr \
	spansion secureip
DIRSKIP = b1553 pci pci/pcif leon2 leon2ft srio idt crypto satcan pci ambatest \
	spacewire ascs slink ftaddr \
	pwm gr1553b iommu ac97 secureip leon4v0 leon3v0 noelvv0

FILESKIP = grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd



OBJCOPY_CMD=sparc-gaisler-elf-objcopy

# For memmap=0
BOPT=
LDFLAGS=

include $(GRLIB)/software/leon5/Makefile
include $(GRLIB)/bin/Makefile


##################  project specific targets ##########################

