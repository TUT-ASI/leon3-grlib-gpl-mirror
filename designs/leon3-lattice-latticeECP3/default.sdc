# Synopsys, Inc. constraint file
# /home/martins/GRLib/from_web/grlib-gpl-1.1.0-b4113/designs/leon3-lattice-latticeECP3/default.sdc
# Written on Fri Mar 23 11:11:37 2012
# by Synplify Pro, D-2010.03-SP1-1 Scope Editor

#
# Collections
#

#
# Clocks
#
define_clock            -name {clk_in} -freq 100.000 -clockgroup default_clkgroup
define_clock            -name {txc} -freq 50.000 -clockgroup phy_tx_clkgroup -route 10.000
define_clock            -name {rxc} -freq 50.000 -clockgroup phy_rx_clkgroup -route 2.000
define_clock            -name {leon3mp|egtx_clk} -freq 125.000 -clockgroup phy_egtx_clkgroup -route 2.000
define_clock            -name {leon3mp|clkgen0.clkin} -freq 100.000 -route 2.0 -clockgroup ahb_clkgroup

#
# Clock to Clock
#

#
# Inputs/Outputs
#
define_output_delay -disable     -default  10.00 -improve 0.00 -route 0.00 -ref {clk:r}
define_input_delay -disable      -default  10.00 -improve 0.00 -route 0.00 -ref {clk:r}

#
# Registers
#

#
# Delay Paths
#

#
# Attributes
#
define_global_attribute  {syn_useioff} {1}

#
# I/O Standards
#

#
# Compile Points
#

#
# Other
#
