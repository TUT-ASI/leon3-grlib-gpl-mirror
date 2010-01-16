# Synplicity, Inc. constraint file
#
# Collections
#

#
# Clocks
#
define_clock  {clk1} -name {clk4}  -freq 25 -clockgroup default_clk1group -route 5
define_clock  {clk2} -name {clk3}  -freq 25 -clockgroup default_clk2group -route 5
define_clock  {clk3} -name {clk2}  -freq 25 -clockgroup default_clk3group -route 5
define_clock  {clk4} -name {clk1}  -freq 25 -clockgroup default_clk4group -route 5

#
# Clock to Clock
#

#
# Inputs/Outputs
#
define_output_delay -disable     -default  5.00 -improve 0.00 -route 0.00 -ref {clk1:r}
define_input_delay -disable      -default  5.00 -improve 0.00 -route 0.00 -ref {clk1:r}

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
# Path Delay
#

#
# Attributes
#
define_global_attribute          syn_useioff {1}
define_global_attribute -disable syn_netlist_hierarchy {0}

#
# I/O standards
#

#
# Compile Points
#

#
# Other Constraints
#
