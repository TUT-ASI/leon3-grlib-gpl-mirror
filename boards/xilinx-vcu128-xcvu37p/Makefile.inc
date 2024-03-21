# FPGA and Dev Board used in Design
TECHNOLOGY=virtexup
PART=xcvu37p
PACKAGE=fsvh2892
PROTOBOARD=xilinx.com:vcu128:part0:1.0
SPEED=2l-e
PROMGENPAR=-u 0 $(TOP).bit -p mcs -data_width 16 -w -o $(BOARD)

# Set Vivado Synthesis Flow Name
VIVADO_SYNTH_FLOW="Vivado Synthesis 2019"

#  Set Vivado Synthesis Synthesis strategy
VIVADO_SYNTH_STRATEGY="Vivado Synthesis Defaults"

# Set Vivado Implementation strategy
VIVADO_IMPL_STRATEGY="Vivado Implementation Defaults"
