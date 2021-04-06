proc doprog {conf} {

puts "-------------------------------------------------------"
puts "Programming the FPGA with NOELV configuration $conf"
puts "-------------------------------------------------------"
cd bitfiles/$conf
open_hw

connect_hw_server
current_hw_target [get_hw_targets]
open_hw_target

# Program and Refresh the Device
current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices] 0]
set_property PROGRAM.FILE {noelvmp.bit} [lindex [get_hw_devices] 0]

program_hw_devices [lindex [get_hw_devices] 0]
refresh_hw_device [lindex [get_hw_devices] 0]

close_hw
exit

}
