# TCL Script for Vivado AXI Register Slice (axi_pipe)

set axi_pipe [create_ip -name axi_register_slice -vendor xilinx.com -library ip -module_name axi_pipe]

# User Parameters
set_property -dict [list \
  CONFIG.DATA_WIDTH {128} \
  CONFIG.ID_WIDTH {4} \
] [get_ips axi_pipe]

# Runtime Parameters
set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $axi_pipe

# Generate output products
generate_target all [get_ips axi_pipe]
