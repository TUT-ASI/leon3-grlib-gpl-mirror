### GRLIB general setup ########################################################

BASE_DIR ?= .
GRLIB 		= $(BASE_DIR)/../..
CORE_DIR ?= $(BASE_DIR)/../noelv-generic/rtl/core
CFG_DIR  ?= $(BASE_DIR)
TB_DIR 	 ?= $(BASE_DIR)/tb
CFG_LOCAL_DIR ?= $(CFG_DIR)/cfg
GRLIB_CONFIG 	?= $(CFG_DIR)/grlib_config.vhd
include $(CFG_DIR)/.config

### RISC-V NOEL-V Core  ########################################################

#32-bit NOEL-V
ifeq ($(CONFIG_NOELV_RV32),y)
DIRADD = l5nv/shared noelv/pkg_32 noelv noelv/core noelv/subsys noelv/grfpunv noelv/dm
XLEN   = 32
else
#64-bit NOEL-V
DIRADD = l5nv/shared noelv/pkg_64 noelv noelv/core noelv/subsys noelv/grfpunv noelv/dm
XLEN   = 64
endif

############  Device  #########################################################
BOARD=lattice-lfcpnx-evn
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)$(SPEED)$(PACKAGE)$(TEMPERATURE)

## Radiant stuff
GRLIB_LATTICE_RADIANT_PERFORMANCE="9_High-Performance_1.0V"
#GRLIB_LATTICE_RADIANT_SYNTHESIS=lse
GRLIB_LATTICE_RADIANT_SIM_DEVICE=lfcpnx
LATTICE_IP=lifcl/pll/pll_125i_35o

CLEAN=soft-clean

## Contraints
PDC=noelvmp.pdc
LDC=noelvmp.ldc
SDCFILE=noelvmp.sdc

############  Project  #########################################################

# Design Top Level
TOP=noelvmp

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
GRLIB_SIMULATOR ?= ModelSim

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
VSIMOPT=

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc" +notimingchecks
else
VSIMOPT+=-voptargs="+acc -nowarn 1" +notimingchecks
endif

# Simulation scripts
VSIMOPT+= -t 10fs
VSIMOPT+= -do $(GRLIB)/bin/runvsim.do
ASIMDO = run -all

# Toplevel
VSIMOPT+= $(SIMTOP)

### Testbench, design and libraries to compile and not to compile ##############

VHDLSYNFILES  =
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

TECHLIBS = nexus

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp gsi cypress hynix ge_1000baseX \
	spansion secureip usb ddr grdmac mmuconfig fmf esa micron
DIRSKIP = b1553 pci gr1553b/core pci/pcif leon2 leon2ft leon5 leon5v0 leon5v0/blockred srio idt crypto satcan pci ambatest \
	ascs slink irqmp grdmac grrm nand\
	pwm gr1553b iommu ac97 secureip mmuiface clk2x leon4v0
FILESKIP = grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd iu4.vhd

### Regenerate AHBROM ##########################################################

ahbrom_gen: prom.exe
	make ahbrom.vhd
	make ahbrom64.vhd
	make ahbrom128.vhd
	mv ahbrom.vhd ahbrom64.vhd ahbrom128.vhd rtl/

prom.exe: prom.elf
	cp prom.elf prom.exe

### Makefile Includes ##########################################################

include $(GRLIB)/software/noelv/systest/Makefile
OBJCOPY_CMD = $(OBJCOPY)

include $(GRLIB)/bin/Makefile

##################  project specific targets ##########################

### Simulation ###
#### Synthesis ###
