# TCL Script for Vivado DDR4 MIG (mig)

set mig [create_ip -name ddr4 -vendor xilinx.com -library ip -module_name mig]

# User Parameters
set_property -dict [list \
  CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
  CONFIG.C0.BANK_GROUP_WIDTH {1} \
  CONFIG.C0.DDR4_AxiAddressWidth {31} \
  CONFIG.C0.DDR4_AxiDataWidth {128} \
  CONFIG.C0.DDR4_AxiSelection {true} \
  CONFIG.C0.DDR4_CLKFBOUT_MULT {6} \
  CONFIG.C0.DDR4_CLKOUT0_DIVIDE {5} \
  CONFIG.C0.DDR4_CasWriteLatency {12} \
  CONFIG.C0.DDR4_DataWidth {64} \
  CONFIG.C0.DDR4_InputClockPeriod {4000} \
  CONFIG.C0.DDR4_MemoryPart {EDY4016AABG-DR-F} \
  CONFIG.C0.DDR4_TimePeriod {833} \
  CONFIG.C0_CLOCK_BOARD_INTERFACE {default_250mhz_clk1} \
  CONFIG.Debug_Signal {Enable} \
] [get_ips mig]

# Runtime Parameters
set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $mig

# Generate output products
generate_target all [get_ips mig]
