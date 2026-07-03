#-----------------------------------------------------------
#                  Constraints                             -
#-----------------------------------------------------------

###Constraints should be competely updated these are only placeholders

# --- Define and constrain system clock

# create_clock -period 3.333 -name clk300 [get_ports {clk300p}]
# set_propagated_clock [get_clocks clk300]

# set_property PACKAGE_PIN AR2        [get_ports {clk300p}]
# set_property IOSTANDARD LVDS15      [get_ports {clk300p}]
# set_property DIFF_TERM_ADV TERM_100 [get_ports {clk300p}]

# set_property PACKAGE_PIN AR1        [get_ports {clk300n}]
# set_property IOSTANDARD LVDS15      [get_ports {clk300n}]
# set_property DIFF_TERM_ADV TERM_100 [get_ports {clk300n}]

# set_max_delay -from [get_ports {clk300?}]  100.0
# set_min_delay -from [get_ports {clk300?}] -100.0


# --- Reset ------------------------------------------------

#set_property PACKAGE_PIN AW2     [get_ports reset]
#set_property IOSTANDARD LVCMOS18 [get_ports reset]


# --- LEDs -------------------------------------------------

set_property PACKAGE_PIN M20 [ get_ports led[0] ] ; # USER_LED_G0
set_property PACKAGE_PIN M21 [ get_ports led[1] ] ; # USER_LED_G1

set_property IOSTANDARD LVCMOS33 [get_ports led*]

set_max_delay -to [ get_ports { led* } ]  100
set_min_delay -to [ get_ports { led* } ] -100


# --- USB UART ---------------------------------------------

set_property PACKAGE_PIN K17 [get_ports duart_rx]
set_property PACKAGE_PIN L18 [get_ports duart_tx]

set_property IOSTANDARD LVCMOS33 [get_ports duart_*]

set_max_delay -to [ get_ports duart_tx ]  100
set_min_delay -to [ get_ports duart_tx ] -100



# --- Programming/bitstream --------------------------------

# Configuration from SPI Flash as per XAPP1233
# Enable bitstream compression
set_property BITSTREAM.GENERAL.COMPRESS {TRUE} [ current_design ]

# Don't pull unused pins up or down
#set_property BITSTREAM.CONFIG.UNUSEDPIN {Pullnone} [current_design]

# Set CFGBVS to GND to match schematics
set_property CFGBVS {GND} [ current_design ]

# Set CONFIG_VOLTAGE to 1.8V to match schematics
set_property CONFIG_VOLTAGE {1.8} [ current_design ]
