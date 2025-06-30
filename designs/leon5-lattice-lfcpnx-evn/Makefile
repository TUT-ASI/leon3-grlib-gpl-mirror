### GRLIB general setup and extra target to clean software

include .config
GRLIB=../..
CLEAN=soft-clean

############  Leon Core  ########################

GRLIB_CONFIG=grlib_config_leon5.vhd

############  Board Setup  ########################

### Device and board setup
BOARD=lattice-lfcpnx-evn
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)$(SPEED)$(PACKAGE)$(TEMPERATURE)

### Radiant stuff
GRLIB_LATTICE_RADIANT_PERFORMANCE="9_High-Performance_1.0V"
#GRLIB_LATTICE_RADIANT_SYNTHESIS=lse
GRLIB_LATTICE_RADIANT_SIM_DEVICE=lfcpnx

############  Project  ########################

### Simulation Options ###
# Design Top Level
TOP=leon5mp

# Simulation top level
SIMTOP=testbench

# Constraints
PDC=leon5mp.pdc
LDC=leon5mp.ldc
SDCFILE=leon5mp.sdc

LATTICE_IP=lifcl/pll/pll_125i_35o

# Uncomment to change to specify your simulator (default is Modelsim)
#GRLIB_SIMULATOR=ALDEC

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
#VSIMOPT= -L secureip -L unisims_ver
#GRLIB_COMPILE_VIVADO_IP=Y


# Simulator switches
# ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
# VSIMOPT+= +access +w -voptargs="+acc -nowarn 1" +notimingchecks
# else
# VSIMOPT+= -voptargs="+acc -nowarn 1" +notimingchecks -64
# endif

# Remove collision check in UNSIM library
# VSIMOPT+= -GSIM_COLLISION_CHECK="GENERATE_X_ONLY"
# ASIMOPT+= -GSIM_COLLISION_CHECK="GENERATE_X_ONLY"

# Toplevel
VSIMOPT= -voptargs="+acc -nowarn 1"
VSIMOPT+= -t 10fs
VSIMOPT+= $(SIMTOP)
VSIMOPT+= -do $(GRLIB)/bin/runvsim.do

### End of Simulation Options ###


### Testbench, design and libraries to compile and not to compile

RTL=$(GRLIB)/designs/$(DESIGN)/rtl
VHDLSYNFILES= config.vhd ahbrom128.vhd leon5mp.vhd $(MEMTECH)
VHDLSIMFILES= testbench.vhd

VERILOGSYNFILES=

TECHLIBS = nexus
SKIP_SIM_TECHLIBS = 1

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp spw hssl gsi cypress hynix ge_1000baseX \
	spansion secureip usb ddr grdmac mmuconfig atf eth micron esa fmf
DIRSKIP = b1553 pci gr1553b/core pci/pcif leon2 leon2ft srio idt crypto satcan pci ambatest ddr \
	spacewire spacefibre ascs slink hssl pwm gr1553b iommu ac97 secureip canfd \
	l2cache/v2 l2cache/v3 l2cache/str axi socbridge grdmac grdmac2 grscrub plic\
	hcan greth noelv noelv/subsys riscv l2c_lite usb nand grrm mma lram

FILESKIP = grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd \
	sf2apbslv_wrapper.vhd sf2ficmst_wrapper.vhd sf2ficslv_wrapper.vhd \
        sf2mddr_wrapper.vhd pfmddr_wrapper.vhd

OBJCOPY_CMD=sparc-gaisler-elf-objcopy

# For memmap=0
BOPT=
LDFLAGS=

include $(GRLIB)/software/leon5/Makefile
include $(GRLIB)/bin/Makefile

##################  project specific targets ##########################
