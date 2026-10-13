# TCL Script for Vivado 1G/2.5G Ethernet PCS/PMA (SGMII)

set sgmii [create_ip -name gig_ethernet_pcs_pma -vendor xilinx.com -library ip -module_name sgmii]

# User Parameters
set_property -dict {
  CONFIG.Standard {SGMII}
  CONFIG.Management_Interface {false}
  CONFIG.DrpClkRate {50}
  CONFIG.InstantiateBitslice0 {true}
} [get_ips sgmii]

# Generate output products
generate_target all [get_ips sgmii]
