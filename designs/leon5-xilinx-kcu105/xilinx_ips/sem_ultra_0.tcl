# TCL Script for Vivado UltraScale Soft Error Mitigation (sem_ultra)

set sem_ultra_0 [create_ip -name sem_ultra -vendor xilinx.com -library ip -module_name sem_ultra_0]

# User Parameters
set_property -dict [list \
  CONFIG.CLOCK_PERIOD {11111} \
  CONFIG.LOCATE_CONFIG_PRIM {example_design} \
] [get_ips sem_ultra_0]

# Runtime Parameters
set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $sem_ultra_0

# Generate output products
generate_target all [get_ips sem_ultra_0]
