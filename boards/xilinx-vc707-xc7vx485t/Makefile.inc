# FPGA and Dev Board used in Design
TECHNOLOGY=Virtex7
PART=XC7VX485T
PACKAGE=ffg1761
PROTOBOARD=xilinx.com:vc707:part0:1.3
SPEED=2
PROMGENPAR=-u 0 $(TOP).bit -p mcs -data_width 16 -w -o $(BOARD)

# Set Vivado Synthesis Flow and Strategy used for build
VIVADO_SYNTH_FLOW="Vivado Synthesis 2018"
VIVADO_SYNTH_STRATEGY="Vivado Synthesis Defaults"
VIVADO_IMPL_STRATEGY="Performance_ExplorePostRoutePhysOpt"

