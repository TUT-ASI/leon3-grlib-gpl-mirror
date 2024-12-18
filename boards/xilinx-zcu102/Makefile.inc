# FPGA and Dev Board used in Design
TECHNOLOGY=zynquplus
PART=xczu9eg
PACKAGE=ffvb1156
PROTOBOARD=xilinx.com:zcu102:part0:3.2
SPEED=2-e
PROMGENPAR=-u 0 $(TOP).bit -p mcs -data_width 16 -w -o $(BOARD)

# Set Vivado Synthesis Flow Name
#VIVADO_SYNTH_FLOW="Vivado Synthesis 2021"
VIVADO_SYNTH_FLOW="Vivado Synthesis 2018"

#  Set Vivado Synthesis Synthesis strategy
VIVADO_SYNTH_STRATEGY="Vivado Synthesis Defaults"

# Set Vivado Implementation strategy
VIVADO_IMPL_STRATEGY="Vivado Implementation Defaults"
