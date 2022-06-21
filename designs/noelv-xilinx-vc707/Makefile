### GRLIB general setup and extra target to clean software
include .config
GRLIB=../..
CLEAN=soft-clean

GRLIB_CONFIG=noelv_config.vhd

DIRADD=noelv/pkg_64 noelv noelv/core noelv/subsys noelv/grfpunv

### Xilinx Vivado device and board setup
BOARD=xilinx-vc707-xc7vx485t
DESIGN=noelv-xilinx-vc707
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)$(PACKAGE)-$(SPEED)
XDC=$(GRLIB)/boards/$(BOARD)/$(BOARD).xdc

### Simulation Options ###
# Design Top Level
TOP=noelvmp

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
#GRLIB_SIMULATOR=ModelSim
#GRLIB_SIMULATOR=ALDEC
#GRLIB_SIMULATOR=Xilinx

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
#VSIMOPT= -gdisas=1

# GRETH options
ifeq ($(CONFIG_GRETH_ENABLE),y)
VSIMOPT+= -L gig_ethernet_pcs_pma -L secureip -L unisims_ver 
GRLIB_COMPILE_VIVADO_IP=y
endif

# - MIG -
ifeq ($(CONFIG_MIG_7SERIES),y)
VSIMOPT+= -t fs -voptargs="+acc -nowarn 1" 
VSIMOPT+= -L secureip -L unisims_ver glbl
ifndef CONFIG_MIG_7SERIES_MODEL
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false -gSIM_BYPASS_INIT_CAL=FAST -gSIMULATION=TRUE -gEXAMPLE_SIMULATION=1
ASIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false -gSIM_BYPASS_INIT_CAL=FAST -gSIMULATION=TRUE -gEXAMPLE_SIMULATION=1
else
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true -t ps -gEXAMPLE_SIMULATION=1
ASIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true -t ps -gEXAMPLE_SIMULATION=1
endif
endif

VIVADO_MIG_AXI=1
GRLIB_XILINX_SOURCE_MGMT_MODE=DisplayOnly
AXI_128=1

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

### Testbench, design and libraries to compile and not to compile

VHDLSYNFILES= config.vhd ahbrom.vhd noelvmp.vhd ddr_dummy.vhd sgmii_vc707.vhd
VHDLSIMFILES=testbench.vhd

TECHLIBS = unisim
SKIP_SIM_TECHLIBS = 1

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp spw gsi cypress hynix \
	spansion secureip grdmac mmuconfig fmf esa micron
DIRSKIP = b1553 pci gr1553b/core pci/pcif leon2 leon2ft srio idt crypto satcan pci ambatest \
	spacewire ascs slink irqmp grdmac grrm nand\
	pwm gr1553b iommu ac97 secureip mmuiface clk2x generic_bm canfd leon4v0 hssl grdmac2 grscrub


ifeq ("$(CONFIG_LEON4)","")
DIRSKIP+=leon4v0
endif
FILESKIP = grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd

### Makefile Includes #################################################

include $(GRLIB)/software/noelv/systest/Makefile
OBJCOPY_CMD = $(OBJCOPY)

include $(GRLIB)/bin/Makefile

##################  project specific targets ##########################
