include .config

GRLIB=../..
TOP=leon3mp

BOARD=digilent-arty-a7
DESIGN=thesign
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
VHDLSYNFILES += $(BOARDDIR)/ahb2mig_arty_a7.vhdl
VHDLSYNFILES += $(BOARDDIR)/clockers_mig.vhdl
VHDLSYNFILES += $(BOARDDIR)/clockers_clkgen.vhdl
VHDLSYNFILES += config.vhd ahbrom.vhd leon3mp.vhd
VHDLSIMFILES=testbench.vhd

SIMTOP=testbench
#SDCFILE=$(BOARDDIR)/default.sdc
FDCFILE=$(BOARDDIR)/default.fdc
BITGEN=$(BOARDDIR)/default.ut
CLEAN=soft-clean

TECHLIBS = unisim
# SKIP_SIM_TECHLIBS = 1

LIBSKIP = core1553bbc core1553brm core1553brt gr1553 corePCIF \
	tmtc openchip ihp usbhc spw
LIBSKIP += esa
LIBSKIP += fmf
LIBSKIP += spansion
LIBSKIP += gsi
LIBSKIP += micron
LIBSKIP += cypress

DIRSKIP = b1553 pci/pcif leon2 leon2ft crypto satcan pci leon3ft ambatest can \
	usb grusbhc spacewire ascs slink hcan \
	leon4v0 l2cache pwm gr1553b iommu
DIRSKIP += grdmac
FILESKIP  =
FILESKIP += grcan.vhd
FILESKIP += adapters/sgmii.vhd
FILESKIP += adapters/rgmii_series7.vhd

# Options used during compilation
VCOMOPT=-explicit -O0

# GRETH options
ifeq ($(CONFIG_GRETH_ENABLE),y)
VSIMOPT+= -L secureip -L unisims_ver -L unisim 
endif

# - MIG -
ifeq ($(CONFIG_MIG_7SERIES),y)
ifndef CONFIG_MIG_7SERIES_MODEL
VSIMOPT+= -t fs -voptargs="+acc -nowarn 1" 
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
VSIMOPT+= -voptargs="+acc -nowarn 1" +notimingchecks
endif

# Simulation scripts
VSIMOPT+= -do wave.do
VSIMOPT+= -do $(GRLIB)/bin/runvsim.do

# Toplevel
VSIMOPT+= $(SIMTOP)

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/leon3/Makefile

EXTRACLEAN += leon3mp.bit.bin
EXTRACLEAN += slack.log

### Synthesize Options ###

VIVADO_IMPL_STRATEGY=Performance_ExplorePostRoutePhysOpt


##################  project specific targets ##########################

vivprog:
	vivado -mode tcl -source doprog.tcl

vivrom:
	vivado -mode tcl -source dorom.tcl

vivslack: vivado/$(DESIGN)/$(DESIGN).runs/impl_1/$(TOP)_routed.dcp
	vivado -mode tcl -nojournal -log slack.log -source slack.tcl $<

copy-mig:
	cp -f $(BOARDDIR)/mig-$(PART)/mig-$(PART).prj vivado/mig.prj
	cp -f $(BOARDDIR)/mig-$(PART)/mig-$(PART).xci vivado/mig.xci
	cp -f $(BOARDDIR)/mig-$(PART)/mig-$(PART).xdc vivado/mig.xdc

vivado-launch: copy-mig
vivado: copy-mig

