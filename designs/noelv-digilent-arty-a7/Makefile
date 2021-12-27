BASE_DIR ?= .
COM_DIR ?= $(BASE_DIR)/rtl/common
CFG_DIR ?= $(BASE_DIR)
CFG_LOCAL_DIR ?= $(CFG_DIR)/cfg
TB_DIR ?= $(BASE_DIR)/tb
include $(CFG_DIR)/.config

GRLIB=$(BASE_DIR)/../..
TOP=noelvmp
GRLIB_CONFIG ?= $(CFG_DIR)/grlib_config.vhd

#PART=XC7A35TI
PART=XC7A100TI

BOARD=digilent-arty-a7
DESIGN=noelv-arty
BOARDDIR=$(GRLIB)/boards/$(BOARD)
include $(BOARDDIR)/Makefile.inc

MGCPART=$(PART)$(PACKAGE)
DEVICE=$(PART)-$(PACKAGE)$(SPEED)
XDC  =
XDC += $(BOARDDIR)/Arty-$(PART).xdc
XDC += $(BOARDDIR)/voltage_config.xdc
XDC += $(BOARDDIR)/mig-$(PART)/mig-$(PART).xdc
EFFORT=high
XSTOPT=-uc leon3mp.xcf
SYNPOPT="set_option -pipe 1; set_option -retiming 1; set_option -write_apr_constraint 0"

# Uncomment for Modelsim or change to specify your simulator
#GRLIB_SIMULATOR=ModelSim
#GRLIB_SIMULATOR=ALDEC

VHDLSYNFILES  =
VHDLSYNFILES += $(BASE_DIR)/rtl/axi_mig3_7series.vhd
VHDLSYNFILES += $(BOARDDIR)/ahb2mig_arty_a7.vhdl
VHDLSYNFILES += $(BOARDDIR)/ahb2axi_mig3_arty_a7.vhd
VHDLSYNFILES += $(BASE_DIR)/rtl/clockers_mig.vhd
VHDLSYNFILES += $(CFG_DIR)/config.vhd
VHDLSYNFILES += $(CFG_LOCAL_DIR)/config_local.vhd
VHDLSYNFILES += $(COM_DIR)/rev.vhd
VHDLSYNFILES += $(COM_DIR)/cfgmap.vhd
VHDLSYNFILES += $(COM_DIR)/noelvcore.vhd
VHDLSYNFILES += $(COM_DIR)/ahbrom.vhd
VHDLSYNFILES += $(BASE_DIR)/rtl/noelvmp.vhd
VHDLSIMFILES  = $(TB_DIR)/testbench.vhd

SIMTOP=testbench
#SDCFILE=$(BOARDDIR)/default.sdc
FDCFILE=$(BOARDDIR)/default.fdc
BITGEN=$(BOARDDIR)/default.ut
CLEAN=soft-clean

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

#32-bit NOEL-V
ifeq ($(CONFIG_NOELV_RV32),y)
DIRSKIP += noelv noelv/subsys
DIRADD = noelv/noelv32
endif

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

# Simulation scripts
VSIMOPT+= -do wave.do
VSIMOPT+= -do $(GRLIB)/bin/runvsim.do

# Toplevel
VSIMOPT+= $(SIMTOP)

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/noelv/systest/Makefile


### Synthesize Options ###

VIVADO_IMPL_STRATEGY=Performance_ExplorePostRoutePhysOpt


##################  project specific targets ##########################

vivprog:
	vivado -mode tcl -source bitfile/doprog.tcl

vivrom:
	vivado -mode tcl -source bitfile/dorom.tcl

vivslack: vivado/$(DESIGN)/$(DESIGN).runs/impl_1/$(TOP)_routed.dcp
	vivado -mode tcl -nojournal -log slack.log -source slack.tcl $<

