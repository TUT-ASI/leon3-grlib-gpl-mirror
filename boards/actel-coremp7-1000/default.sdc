# Synplicity, Inc. constraint file
# /home/jiri/ibm/vhdl/grlib/boards/actel-coremp7-1000/default.sdc
# Written on Wed Aug  1 19:29:24 2007
# by Synplify Pro, Synplify Pro 8.8.0.4 Scope Editor

#
# Collections
#

#
# Clocks
#
define_clock  {clk} -name {clk}  -freq 48 -clockgroup default_clkgroup -route 5

#
# Clock to Clock
#

#
# Inputs/Outputs
#
define_output_delay -disable     -default  5.00 -improve 0.00 -route 0.00 -ref {clk:r}
define_input_delay -disable      -default  5.00 -improve 0.00 -route 0.00 -ref {clk:r}
define_output_delay -disable     -default  14.00 -improve 0.00 -route 0.00 -ref {pci_clk:r}
define_input_delay -disable      -default  18.00 -improve 0.00 -route 0.00 -ref {pci_clk:r}
define_input_delay -disable      {pci_rst}  0.00 -improve 0.00 -route 0.00 -ref {pci_clk:r}

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
define_attribute          {etx_clk} syn_noclockbuf {1}

#
# I/O standards
#

#
# Compile Points
#

#
# Other Constraints
#
