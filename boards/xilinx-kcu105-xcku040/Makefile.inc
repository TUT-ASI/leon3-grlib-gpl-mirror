# FPGA and Dev Board used in Design
TECHNOLOGY=KintexU
PART=xcku040
PACKAGE=ffva1156
#PROTOBOARD=xilinx.com:kcu105:part0:1.7
PROTOBOARD=xilinx.com:kcu105:part0:1.4
SPEED=2-e
PROMGENPAR=-u 0 $(TOP).bit -p mcs -data_width 16 -w -o $(BOARD)

# Set Vivado Synthesis Flow Name
#VIVADO_SYNTH_FLOW="Vivado Synthesis 2021"
VIVADO_SYNTH_FLOW="Vivado Synthesis 2018"

#  Set Vivado Synthesis Synthesis strategy
VIVADO_SYNTH_STRATEGY="Vivado Synthesis Defaults"

# Set Vivado Implementation strategy
VIVADO_IMPL_STRATEGY="Vivado Implementation Defaults"
