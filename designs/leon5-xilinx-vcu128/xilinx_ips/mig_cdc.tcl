# TCL Script for Vivado AXI Clock Converter (mig_cdc)

set mig_cdc [create_ip -name axi_clock_converter -vendor xilinx.com -library ip -module_name mig_cdc]

# User Parameters
set_property -dict [list \
  CONFIG.DATA_WIDTH {512} \
  CONFIG.ID_WIDTH {4} \
] [get_ips mig_cdc]

# Runtime Parameters
set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $mig_cdc

# Generate output products
generate_target all [get_ips mig_cdc]
