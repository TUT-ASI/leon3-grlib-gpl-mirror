# TCL Script for Vivado DDR4 MIG (mig)

set mig [create_ip -name ddr4 -vendor xilinx.com -library ip -module_name mig]

# User Parameters
set_property -dict [list \
  CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
  CONFIG.C0.BANK_GROUP_WIDTH {1} \
  CONFIG.C0.DDR4_AxiAddressWidth {31} \
  CONFIG.C0.DDR4_AxiDataWidth {128} \
  CONFIG.C0.DDR4_AxiNarrowBurst {true} \
  CONFIG.C0.DDR4_AxiSelection {true} \
  CONFIG.C0.DDR4_CLKFBOUT_MULT {4} \
  CONFIG.C0.DDR4_DataWidth {64} \
  CONFIG.C0.DDR4_InputClockPeriod {3332} \
  CONFIG.C0.DDR4_MemoryPart {EDY4016AABG-DR-F} \
  CONFIG.C0.DDR4_Specify_MandD {true} \
  CONFIG.C0_CLOCK_BOARD_INTERFACE {Custom} \
  CONFIG.Debug_Signal {Enable} \
  CONFIG.RESET_BOARD_INTERFACE {Custom} \
] [get_ips mig]

# Runtime Parameters
set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $mig

# Generate output products
generate_target all [get_ips mig]
