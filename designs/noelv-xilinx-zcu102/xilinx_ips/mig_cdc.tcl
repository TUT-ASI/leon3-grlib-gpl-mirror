set mig_cdc [create_ip -name axi_clock_converter -vendor xilinx.com -library ip -module_name mig_cdc]

set_property -dict { 
  CONFIG.DATA_WIDTH {128}
  CONFIG.ID_WIDTH {4}
  CONFIG.ACLK_ASYNC {1}
  CONFIG.ACLK_RATIO {1:2}
} [get_ips mig_cdc]

# Generate output products
generate_target all [get_ips mig_cdc]

