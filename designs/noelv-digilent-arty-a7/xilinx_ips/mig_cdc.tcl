##################################################################
# CREATE IP mig_cdc
##################################################################

set axi_clock_converter mig_cdc
create_ip -name axi_clock_converter -vendor xilinx.com -library ip -module_name $axi_clock_converter

set_property -dict { 
  CONFIG.ADDR_WIDTH {32}
  CONFIG.DATA_WIDTH {128}
  CONFIG.ID_WIDTH {4}
  CONFIG.ACLK_ASYNC {1}
  CONFIG.SYNCHRONIZATION_STAGES {3}
  CONFIG.ACLK_RATIO {1:2}
} [get_ips $axi_clock_converter]

generate_target all [get_ips $axi_clock_converter]

##################################################################

