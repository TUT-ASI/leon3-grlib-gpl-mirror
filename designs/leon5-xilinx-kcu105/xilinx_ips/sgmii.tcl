# TCL Script for Vivado 1G/2.5G Ethernet PCS/PMA (SGMII)

set sgmii [create_ip -name gig_ethernet_pcs_pma -vendor xilinx.com -library ip -module_name sgmii]

# User Parameters
set_property -dict [list \
  CONFIG.DIFFCLK_BOARD_INTERFACE {sgmii_phyclk} \
  CONFIG.Standard {SGMII} \
  CONFIG.Physical_Interface {LVDS} \
  CONFIG.Management_Interface {false} \
  CONFIG.Auto_Negotiation {true} \
  CONFIG.SupportLevel {Include_Shared_Logic_in_Core} \
  CONFIG.LvdsRefClk {625} \
] [get_ips sgmii]

# Runtime Parameters
set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $sgmii

# Generate output products
generate_target all [get_ips sgmii]
