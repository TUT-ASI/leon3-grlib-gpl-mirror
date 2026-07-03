# FPGA and Dev Board used in Design
TECHNOLOGY=KintexU
PART=xcvc1902
PACKAGE=vsva2197

SPEED=2MP-e-S
#PROMGENPAR=-u 0 $(TOP).bit -p mcs -data_width 16 -w -o $(BOARD)

# Set Vivado Synthesis Flow Name
VIVADO_SYNTH_FLOW="Vivado Synthesis 2022"

#  Set Vivado Synthesis Synthesis strategy
VIVADO_SYNTH_STRATEGY="Vivado Synthesis Defaults"

# Set Vivado Implementation strategy
VIVADO_IMPL_STRATEGY="Vivado Implementation Defaults"
