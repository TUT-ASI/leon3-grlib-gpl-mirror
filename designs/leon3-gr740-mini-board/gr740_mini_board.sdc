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
#create_clock -name {clkm} -period 10 [get_nets clkm]
create_clock -name {clk_in_125mhz} -period 8 [get_ports clk_in_125mhz]
create_clock -name {clkm} -period 20 [get_nets clkm]
create_clock -name {clk_in_33mhz} -period 30.3030303030303 [get_ports clk_in_33mhz]
create_clock -name {eth_rxclk} -period 8 [get_ports eth_rxclk]
create_clock -name {eth_txclk} -period 40 [get_ports eth_txclk]
set_false_path -from [get_clocks clk_in_33mhz] -to [get_clocks clkm]
set_false_path -from [get_clocks clkm] -to [get_clocks clk_in_33mhz]
set_false_path -from [get_clocks clk_in_125mhz] -to [get_clocks clkm]
set_false_path -from [get_clocks clkm] -to [get_ports clk_in_125mhz]
set_false_path -from [get_nets clk100] -to [get_clocks clkm]
set_false_path -from [get_clocks clkm] -to [get_nets clk100]
set_false_path -from [get_clocks eth_rxclk] -to [get_clocks clkm]
set_false_path -from [get_clocks clkm]

# JTAG CLOCK
# Arbitrarily assign a 10 MHz clock signal on the dedicated JTAG clock pin.
# In practice this clock is completely asynchronous to clkm since it is
# provided by an external debugger/USB-serial converter. And there is an
# internal clock-domain crossing between the clkm and tck clock domains.
# But simply marking the clock domains as asynchronous with a constraint is
# not appropriate because that simply ignores timing between the domains and
# it has been observed that (without timing constraints) Radiant will
# occasionally place the AHBJTAG far enough away from the JTAG macro that the
# routing delay is too large and causes the clock-domain crossing to become
# unreliable.
#
# An alternative could be set_max_delay, but the results were not encouraging.
# Instead we enforce a reasonable timing constraint by setting the TCK frequency
# to be a submultiple of the clkm frequency. In the absence of other constraints,
# Synplify will consider tck and clkm synchronous and find that the worst-case
# separation of two clock edges is one clkm-period and will constrain propagation
# delays to be roughly within one clkm-period in both directions. This should be
# sufficient to make the AHBJTAG clock-domain transition reliable. However, if the
# clkm-frequency is changed, it is important to update the tck-constraint as well
# to keep the tck-frequency a submultiple of the clkm-frequency.
create_clock -name {tck} -period 100 [get_ports tck]
