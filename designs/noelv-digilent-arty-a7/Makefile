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
DIRADD = noelv/pkg_32 noelv noelv/core noelv/subsys noelv/grfpunv
XLEN   = 32
else
#64-bit NOEL-V
DIRADD = noelv/pkg_64 noelv noelv/core noelv/subsys noelv/grfpunv
XLEN   = 64
endif

############  Board Setup  ########################

#PART=XC7A35TI
PART=XC7A100TI
BOARD=digilent-arty-a7
DESIGN=noelv-digilent-arty-a7
BOARDDIR=$(GRLIB)/boards/$(BOARD)
include $(BOARDDIR)/Makefile.inc

MGCPART=$(PART)$(PACKAGE)
DEVICE=$(PART)-$(PACKAGE)$(SPEED)
XDC  =
XDC += $(BOARDDIR)/Arty-$(PART).xdc
XDC += $(BOARDDIR)/voltage_config.xdc
XDC += $(BOARDDIR)/mig-$(PART)/mig-$(PART).xdc
XDC += $(BASE_DIR)/noelvmp_jtag.xdc

#SDCFILE=$(BOARDDIR)/default.sdc
FDCFILE=$(BOARDDIR)/default.fdc
BITGEN=$(BOARDDIR)/default.ut

############  Project  ########################

### Synthesize Options ###
EFFORT=high
XSTOPT=-uc leon3mp.xcf
SYNPOPT="set_option -pipe 1; set_option -retiming 1; set_option -write_apr_constraint 0"
VIVADO_IMPL_STRATEGY=Performance_ExplorePostRoutePhysOpt
### End of Synthesize Options ###

### Simulation Options ###
# Design Top Level
TOP=noelvmp

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
#GRLIB_SIMULATOR=ModelSim
#GRLIB_SIMULATOR=ALDEC

# Options used during compilation
VCOMOPT=-explicit -O0

# GRETH options
ifeq ($(CONFIG_GRETH_ENABLE),y)
VSIMOPT+= -L secureip -L unisims_ver -L unisim 
endif

# - MIG -
ifeq ($(CONFIG_MIG_7SERIES),y)
VIVADO_MIG_AXI=1
AXI_128=1
ifndef CONFIG_MIG_7SERIES_MODEL
VSIMOPT+= -t fs -voptargs="+acc" 
VSIMOPT+= -L secureip_ver -L xilinxcorelib_ver -L unisims_ver glbl
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=false
else
VSIMOPT+= -gUSE_MIG_INTERFACE_MODEL=true -t ps
GHDLRUNOPT+= -gUSE_MIG_INTERFACE_MODEL=true
endif
endif
# GHDL does not like the unisim clkgen for some reason
GHDLRUNOPT+= -gclktech=0

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc" +notimingchecks
else
VSIMOPT+= -voptargs="+acc" +notimingchecks
endif

GRLIB_XILINX_SOURCE_MGMT_MODE=DisplayOnly

# Simulation scripts
VSIMOPT+= -do wave.do
VSIMOPT+= -do $(GRLIB)/bin/runvsim.do

# Toplevel
VSIMOPT+= $(SIMTOP)

### Testbench, design and libraries to compile and not to compile

VHDLSYNFILES  =
VHDLSYNFILES += $(BASE_DIR)/rtl/axi_mig3_7series.vhd
VHDLSYNFILES += $(BOARDDIR)/ahb2axi_mig3_arty_a7.vhd
VHDLSYNFILES += $(BASE_DIR)/rtl/clockers_mig.vhd
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

LIBSKIP = core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip ihp usbhc spw
LIBSKIP += opencores
LIBSKIP += esa
LIBSKIP += fmf
LIBSKIP += spansion
LIBSKIP += gsi
LIBSKIP += micron
LIBSKIP += cypress

DIRSKIP = b1553 pci/pcif leon2 leon2ft crypto satcan pci leon3ft ambatest can \
	usb grusbhc spacewire ascs slink hcan \
	leon4v0 l2cache pwm gr1553b iommu
DIRSKIP += i2c
DIRSKIP += spi
DIRSKIP += grdmac
FILESKIP  =
FILESKIP += grcan.vhd
FILESKIP += adapters/sgmii.vhd
FILESKIP += adapters/rgmii_series7.vhd

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

vivprog:
	vivado -mode tcl -source bitfile/doprog.tcl

vivrom:
	vivado -mode tcl -source bitfile/dorom.tcl

vivslack: vivado/$(DESIGN)/$(DESIGN).runs/impl_1/$(TOP)_routed.dcp
	vivado -mode tcl -nojournal -log slack.log -source slack.tcl $<

