#
# Clocks
#
#define_clock            -name {leon3mp|clkm} {n:clkm}  -freq 50.000 -route 5.0  -clockgroup default_clkgroup
#
# Inputs/Outputs
#
#
# Registers
#
#
# Multicycle Path
#
#
# False Path
#
#
# Attributes
#
#define_global_attribute          syn_useioff {1}
#
# Other Constraints
#
create_clock -name {clkm} -period 28.571429 [get_nets clkm]
