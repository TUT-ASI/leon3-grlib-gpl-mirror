# Synplicity, Inc. constraint file
# /home/jiri/ibm/vhdl/grlib/designs/leon3-avnet-eval-xc4vlx25/default.sdc
# Written on Sun Oct  1 16:16:08 2006
# by Synplify Pro, Synplify Pro 8.6.1 Scope Editor

#
# Collections
#

#
# Clocks
#
define_clock            -name {etx_clk}  -freq 25.000 -clockgroup phy_rx_clkgroup -route 10.000
define_clock            -name {erx_clk}  -freq 25.000 -clockgroup phy_tx_clkgroup -route 10.000

define_clock            -name {clk} -freq 40.000 -route 5.0 -clockgroup ddr_clkgroup
define_clock            -name {clk125}  -freq 125.000 -route 2.0 -clockgroup ahb_clkgroup

#
# Clock to Clock
#
#define_clock_delay           -rise {clk_100mhz} -fall {clk_100mhz} -false

#
# Inputs/Outputs
#
define_output_delay -disable     -default  10.00 -improve 0.00 -route 0.00 -ref {clk:r}
define_input_delay -disable      -default  10.00 -improve 0.00 -route 0.00 -ref {clk:r}

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

#
# I/O standards
#

#
# Compile Points
#

#
# Other Constraints
#
