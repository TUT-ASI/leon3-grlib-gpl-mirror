# FPGA and Dev Board used in Design
TECHNOLOGY=kintex7
PART=xc7a200t
PACKAGE=fbg676
PROTOBOARD=xilinx.com:artix7:ac701:1.0
SPEED=2
PROMGENPAR=-x xcf08p -u 0 $(TOP).bit -p mcs -w -o $(BOARD)

# Set Vivado Synthesis Flow and Strategy used for build
# Choose 'XST 14' or 'Vivado Synthesis 2012'
#VIVADO_SYNTH_FLOW="Vivado Synthesis 2012"

# For 'Vivado Synthesis 2012' flow set:
#    1. 'Vivado Synthesis Defaults'
# For 'XST 14'flow set:
#    1. 'TimingWithIOBPacking'
#    2. 'TimingWithoutIOBPacking'
#    3. 'AreaReduction'
#    4. 'PowerOptimization'
#    5. 'XST Defaults'
#VIVADO_SYNTH_STRATEGY="Vivado Synthesis Defaults"

# Set Vivado Implementation strategy
#   1. 'HighEffort'
#   2. 'HighEffortPhySynth'
#   3. 'Vivado Implemnation Defaults'
#   4. 'LowEffort'
#   5. 'QuickEffort'
#VIVADO_IMPL_STRATEGY="HighEffortPhySynth"
