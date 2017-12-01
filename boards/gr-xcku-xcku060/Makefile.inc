# FPGA and Dev Board used in Design
TECHNOLOGY=KintexU
PART=XCKU060
PACKAGE=ffva1156
#PROTOBOARD=xilinx.com:kc705:part0:1.0
SPEED=1-C
PROMGENPAR=-u 0 $(TOP).bit -p mcs -data_width 16 -w -o $(BOARD)

# Set Vivado Synthesis Flow Name
VIVADO_SYNTH_FLOW="Vivado Synthesis 2012"

#  Set Vivado Synthesis Synthesis strategy
VIVADO_SYNTH_STRATEGY="Vivado Synthesis Defaults"

# Set Vivado Implementation strategy
VIVADO_IMPL_STRATEGY="Vivado Implementation Defaults"
