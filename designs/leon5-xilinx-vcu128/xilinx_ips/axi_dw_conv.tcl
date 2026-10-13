# TCL Script for Vivado AXI Data Width Converter (axi_dw_conv)

set axi_dw_conv [create_ip -name axi_dwidth_converter -vendor xilinx.com -library ip -module_name axi_dw_conv]

# User Parameters
set_property -dict [list \
  CONFIG.MI_DATA_WIDTH {512} \
  CONFIG.SI_DATA_WIDTH {128} \
  CONFIG.SI_ID_WIDTH {4} \
] [get_ips axi_dw_conv]

# Runtime Parameters
set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $axi_dw_conv

# Generate output products
generate_target all [get_ips axi_dw_conv]
