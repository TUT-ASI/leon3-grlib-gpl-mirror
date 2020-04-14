open_hw

connect_hw_server
# connect_hw_server -url localhost:3121
# current_hw_target [lindex [get_hw_targets] 0]

current_hw_target [get_hw_targets]

open_hw_target


# Program and Refresh the XC7K325T Device

current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices] 0]
set_property PROGRAM.FILE {leon3mp.bit} [lindex [get_hw_devices] 0]
# set_property PROBES.FILE {C:/design.ltx} [lindex [get_hw_devices] 0]

program_hw_devices [lindex [get_hw_devices] 0]
refresh_hw_device [lindex [get_hw_devices] 0]

exit

