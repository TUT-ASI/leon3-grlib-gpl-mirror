### GRLIB general setup and extra target to clean software

############  RISC-V NOEL-V Core  ########################

BASE_DIR ?= .
GRLIB 		= $(BASE_DIR)/../..
CORE_DIR ?= $(BASE_DIR)/../noelv-generic/rtl/core
CFG_DIR  ?= $(BASE_DIR)
TB_DIR 	 ?= $(BASE_DIR)/tb
CFG_LOCAL_DIR ?= $(CFG_DIR)/cfg
GRLIB_CONFIG 	?= $(CFG_DIR)/grlib_config.vhd
include $(CFG_DIR)/.config

### RISC-V NOEL-V Core  ##################################

#32-bit NOEL-V
ifeq ($(CONFIG_NOELV_RV32),y)
DIRADD = noelv/pkg_32 noelv noelv/core noelv/dm noelv/subsys noelv/grfpunv
XLEN   = 32
else
#64-bit NOEL-V
DIRADD = noelv/pkg_64 noelv noelv/core noelv/dm noelv/subsys noelv/grfpunv
XLEN   = 64
endif

############  Board Setup  ########################

### Xilinx Vivado device and board setup
BOARD=xilinx-kcu105-xcku040
DESIGN=noelv-xilinx-kcu105
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)-$(SPEED)
XDC  = $(GRLIB)/boards/$(BOARD)/$(BOARD).xdc
XDC += $(BASE_DIR)/noelvmp_jtag.xdc

############  Project  ########################

### Simulation Options ###
# Design Top Level
TOP=noelvmp

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
GRLIB_SIMULATOR=ModelSim

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
VSIMOPT= -gdisas=0 -L secureip -L unisims_ver

# GRETH options
ifeq ($(CONFIG_GRETH_ENABLE),y)
VSIMOPT+= -L gig_ethernet_pcs_pma_v16_1_1
endif

# MIG (TODO)
ifeq ($(CONFIG_MIG_7SERIES),y)
VSIMOPT+= -t 1ps -novopt
ifndef CONFIG_MIG_7SERIES_MODEL
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false
ASIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false
else
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true -t ps
ASIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true -t ps
endif
endif

# Use MIG with AXI interface with width=64 when AXI4 interface is selected
ifeq ($(CONFIG_MIG_7SERIES),y)
VIVADO_MIG_AXI=1
AXI_128=1
endif
VIVADO_IMPL_STRATEGY = Performance_ExplorePostRoutePhysOpt

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc" +notimingchecks
else
VSIMOPT+=-novopt +notimingchecks
endif

GRLIB_XILINX_SOURCE_MGMT_MODE=DisplayOnly

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

### End of Synthesize Options ###

### Testbench, design and libraries to compile and not to compile

VHDLSYNFILES  = 
VHDLSYNFILES += $(BASE_DIR)/rtl/ddr4ram.vhd
VHDLSYNFILES += $(BASE_DIR)/rtl/axi_mig4_7series.vhd
VHDLSYNFILES += $(BASE_DIR)/rtl/sgmii_kcu105.vhd
VHDLSYNFILES += $(CFG_DIR)/config.vhd
VHDLSYNFILES += $(CFG_LOCAL_DIR)/config_local.vhd
VHDLSYNFILES += $(CORE_DIR)/rev.vhd
VHDLSYNFILES += $(CORE_DIR)/cfgmap.vhd
VHDLSYNFILES += $(CORE_DIR)/noelvcore.vhd
VHDLSYNFILES += $(BASE_DIR)/rtl/ahbrom.vhd
VHDLSYNFILES += $(BASE_DIR)/rtl/ahbrom64.vhd
VHDLSYNFILES += $(BASE_DIR)/rtl/ahbrom128.vhd
VHDLSYNFILES += $(BASE_DIR)/rtl/noelvmp.vhd 
VHDLSIMFILES  = $(TB_DIR)/testbench.vhd 

TECHLIBS = unisim
SKIP_SIM_TECHLIBS = 1

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp spw gsi cypress hynix ge_1000baseX \
	spansion secureip usb ddr grdmac mmuconfig fmf esa micron spfi
DIRSKIP = b1553 pci gr1553b/core pci/pcif leon2 leon2ft leon5 leon5v0 leon5v0/blockred srio idt crypto satcan pci ambatest \
	spacewire ascs slink irqmp grdmac grrm nand\
	pwm gr1553b iommu ac97 secureip mmuiface clk2x canfd leon4v0 hssl
FILESKIP = grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd iu4.vhd

### Regenerate AHBROM #################################################

ahbrom_gen: prom.exe
	make ahbrom.vhd
	make ahbrom64.vhd
	make ahbrom128.vhd
	mv ahbrom.vhd ahbrom64.vhd ahbrom128.vhd rtl/

prom.exe: prom.elf
	cp prom.elf prom.exe

### Makefile Includes #################################################

include $(GRLIB)/software/noelv/systest/Makefile
OBJCOPY_CMD = $(OBJCOPY)

include $(GRLIB)/bin/Makefile

##################  project specific targets ##########################

### Simulation ###
#### Synthesis ###
