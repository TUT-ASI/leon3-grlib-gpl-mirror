# The Digilent provided xdc file lacks the voltage config. Provided here to
# silent some DRC warnings.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

