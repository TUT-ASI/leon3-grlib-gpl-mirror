### GRLIB general setup and extra target to clean software

include .config
GRLIB=../..
CLEAN=soft-clean

############  Leon Core  ########################

GRLIB_CONFIG=grlib_config.vhd

############  Board Setup  ########################

### Xilinx Vivado device and board setup
BOARD=xilinx-kcu105-xcku040
DESIGN=leon3-xilinx-kcu105
include $(GRLIB)/boards/$(BOARD)/Makefile.inc
DEVICE=$(PART)-$(PACKAGE)-$(SPEED)
XDC=$(GRLIB)/boards/$(BOARD)/$(BOARD).xdc

############  Project  ########################

### Simulation Options ###
# Design Top Level
TOP=leon3mp

# Simulation top level
SIMTOP=testbench

# Uncomment for Modelsim or change to specify your simulator
GRLIB_SIMULATOR=ModelSim

# Options used during compilation
VCOMOPT=-explicit -O0

# GRLIB Options
VSIMOPT= -L work -L secureip -L unisims_ver glbl
GRLIB_COMPILE_VIVADO_IP=Y

# GRETH options
ifeq ($(CONFIG_GRETH_ENABLE),y)
VSIMOPT+= -L gig_ethernet_pcs_pma_v16_1_3
endif

# - MIG -
ifeq ($(CONFIG_MIG_7SERIES),y)
VSIMOPT+= -t ps -voptargs="+acc -nowarn 1"
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
AXI_64=1
endif

# Simulator switches
ifeq ("$(GRLIB_SIMULATOR)","ALDEC")
VSIMOPT+= +access +w -voptargs="+acc -nowarn 1" +notimingchecks
else
VSIMOPT+= -voptargs="+acc -nowarn 1" +notimingchecks
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

VIVADO_IMPL_STRATEGY=Performance_ExplorePostRoutePhysOpt

### End of Synthesize Options ###

### Testbench, design and libraries to compile and not to compile

RTL=$(GRLIB)/designs/$(DESIGN)/rtl

VHDLSYNFILES= rtl/ddr4ram.vhd rtl/axi_mig4_7series.vhd rtl/ahb2axi_mig4_7series.vhd rtl/sgmii_kcu105.vhd \
		config.vhd ahbrom.vhd leon3mp.vhd $(MEMTECH)
VHDLSIMFILES= testbench.vhd 

VERILOGSYNFILES=

TECHLIBS = unisim
SKIP_SIM_TECHLIBS = 1

LIBSKIP = pci pci/pcif core1553bbc core1553brm srio core1553brt idt gr1553 corePCIF \
	tmtc openchip ihp gsi cypress hynix ge_1000baseX \
	spansion secureip usb ddr grdmac mmuconfig atf micron \
	esa fmf
LIBADD = testgrouppolito
DIRSKIP = b1553 pci gr1553b/core pci/pcif leon2 leon2ft srio idt crypto satcan pci ambatest \
	ascs slink  \
	pwm gr1553b iommu ac97 secureip canfd \
	nand grrm mma lram riscv noelv noelv/subsys
ifeq ("$(CONFIG_LEON4)","")
DIRSKIP+=leon4v0
endif
FILESKIP = grcan.vhd ddr2.v mobile_ddr.v adapters/sgmii.vhd

include $(GRLIB)/bin/Makefile
include $(GRLIB)/software/leon3/Makefile


##################  project specific targets ##########################

### Local Simulation Targets ###

lib-map: modelsim.ini
	@vmap xpm ./xilinx_lib/xpm
	@vmap microblaze_v10_0_6 ./xilinx_lib/microblaze_v10_0_6
	@vmap lib_cdc_v1_0_2 ./xilinx_lib/lib_cdc_v1_0_2
	@vmap proc_sys_reset_v5_0_12 ./xilinx_lib/proc_sys_reset_v5_0_12
	@vmap lmb_v10_v3_0_9 ./xilinx_lib/lmb_v10_v3_0_9
	@vmap lmb_bram_if_cntlr_v4_0_14 ./xilinx_lib/lmb_bram_if_cntlr_v4_0_14
	@vmap blk_mem_gen_v8_4_1 ./xilinx_lib/blk_mem_gen_v8_4_1
	@vmap iomodule_v3_1_3 ./xilinx_lib/iomodule_v3_1_3

INCDIR = "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/ip_1/rtl/clocking" "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/ip_1/rtl/map" "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/rtl/ip_top" "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/rtl/cal" "+incdir+$(XILINX_VIVADO)/data/xilinx_vip/include" "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/ip_1/rtl/map" "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/rtl/ip_top" "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/ip/mig/rtl/cal" "+incdir+$(XILINX_VIVADO)/data/xilinx_vip/include"

mig_ddr4: mig_7series
	@echo "DDR4 SDRAM MIG IP";
	@vmap xpm ./xilinx_lib/xpm
	@vmap microblaze_v10_0_6 ./xilinx_lib/microblaze_v10_0_6
	@vmap lib_cdc_v1_0_2 ./xilinx_lib/lib_cdc_v1_0_2
	@vmap proc_sys_reset_v5_0_12 ./xilinx_lib/proc_sys_reset_v5_0_12
	@vmap lmb_v10_v3_0_9 ./xilinx_lib/lmb_v10_v3_0_9
	@vmap lmb_bram_if_cntlr_v4_0_14 ./xilinx_lib/lmb_bram_if_cntlr_v4_0_14
	@vmap blk_mem_gen_v8_4_1 ./xilinx_lib/blk_mem_gen_v8_4_1
	@vmap iomodule_v3_1_3 ./xilinx_lib/iomodule_v3_1_3
	@echo "Link and include XPM Memory";
	vlog -work work -64 -incr -sv -L work $(XILINX_VIVADO)/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv;
	vlog $(INCDIR) -work work -64 -incr -sv -L work ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/ip_1/rtl/*/*.sv;
	vlog $(INCDIR) -work work -64 -incr -sv -L work ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/rtl/*/*.sv;
	@echo "Compile Microblaze source files";
	vcom -work microblaze_v10_0_6 -64 -93 ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_0/hdl/microblaze_*.vhd;
	vcom -work lib_cdc_v1_0_2 -64 -93 ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_1/hdl/lib_cdc_*.vhd;
	vcom -work proc_sys_reset_v5_0_12 -64 -93 ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_1/hdl/proc_sys_reset_*.vhd;
	vcom -work lmb_v10_v3_0_9 -64 -93 ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_2/hdl/lmb_*.vhd;
	vcom -work lmb_bram_if_cntlr_v4_0_14 -64 -93 ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_4/hdl/lmb_bram_if_cntlr_*.vhd;
	vcom -work iomodule_v3_1_3 -64 -93 ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_10/hdl/iomodule_*.vhd;
	vcom -work xpm -64 -93 $(XILINX_VIVADO)/data/ip/xpm/xpm_VCOMP.vhd;
	vlog -work work $(XILINX_VIVADO)/data/verilog/src/glbl.v;
	vcom -work work -64 -93 ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_1/sim/bd_bae1_rst_0_0.vhd \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_2/sim/bd_bae1_ilmb_0.vhd \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_3/sim/bd_bae1_dlmb_0.vhd \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_3/sim/bd_bae1_dlmb_0.vhd \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_4/sim/bd_bae1_dlmb_cntlr_0.vhd \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_5/sim/bd_bae1_ilmb_cntlr_0.vhd \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_5/sim/bd_bae1_ilmb_cntlr_0.vhd \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_0/sim/bd_bae1_microblaze_I_0.vhd \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_10/hdl/iomodule_v3_1_vh_rfs.vhd \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_10/sim/bd_bae1_iomodule_0_0.vhd \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_7/sim/bd_bae1_second_dlmb_cntlr_0.vhd \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_8/sim/bd_bae1_second_ilmb_cntlr_0.vhd;
	vlog -work work -64 -incr "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/ip_1/rtl/map" "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/rtl/ip_top" "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/rtl/cal" "+incdir+$(XILINX_VIVADO)/data/xilinx_vip/include" "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/ip_1/rtl/map" "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/rtl/ip_top" "+incdir+./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/rtl/cal" "+incdir+$(XILINX_VIVADO)/data/xilinx_vip/include" \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_6/sim/bd_bae1_lmb_bram_I_0.v \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_9/sim/bd_bae1_second_lmb_bram_I_0.v \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/sim/bd_bae1.v \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/bd_0/ip/ip_6/simulation/blk_mem_gen_*.v \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig/ip_0/sim/mig_microblaze_mcs.v;
	@echo "Compile DDR4 Memory Model";
	vlog -suppress 12110 -novopt -work work +acc -sv +define+DDR4_4G_X16 \
	./model/arch_package.sv \
	./model/proj_package.sv \
	./model/interface.sv \
	./model/StateTable.svp \
	./model/MemoryArray.svp \
	./model/ddr4_model.svp;

sgmii_kcu105: modelsim.ini
	@echo "SGMII IP";
	@vmap gig_ethernet_pcs_pma_v16_1_3 ./xilinx_lib/gig_ethernet_pcs_pma_v16_1_3
	if [ -f ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/sgmii/hdl/gig_ethernet_pcs_pma_v16_1_rfs.v ]; then \
	vlog -work work ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/sgmii/hdl/gig_ethernet_pcs_pma_*.v; \
	vlog -work work $(XILINX_VIVADO)/data/verilog/src/glbl.v; \
	vlog -work work \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/sgmii/synth/*/*.v \
	./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/sgmii/synth/*.v ;\
	fi;

cdc: modelsim.ini
	@echo "Clock Domain Crossing AXI4 IP";
	@vmap axi_clock_converter_v2_1_15 ./xilinx_lib/axi_clock_converter_v2_1_15
	@vmap fifo_generator_v13_2_2 ./xilinx_lib/fifo_generator_v13_2_2
	@vmap axi_infrastructure_v1_1_0 ./xilinx_lib/axi_infrastructure_v1_1_0
	vlog -work work ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig_cdc/hdl/*.v;
	vlog -work work ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig_cdc/simulation/*.v;
	vcom -work fifo_generator_v13_2_2 -64 -93 ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig_cdc/hdl/fifo_*.vhd;
	vlog -work work ./vivado/$(DESIGN)/$(DESIGN).srcs/sources_1/ip/mig_cdc/synth/mig_cdc.v;

gen_ips:
	vivado -mode batch -source ./vivado/$(TOP)_vivado.tcl

ips: gen_ips mig_ddr4 sgmii_kcu105 cdc
