# TCL Script for Vivado DDR4 MIG (mig)

set mig [create_ip -name ddr4 -vendor xilinx.com -library ip -module_name mig]

# User Parameters
set_property -dict [list \
  CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
  CONFIG.C0.BANK_GROUP_WIDTH {1} \
  CONFIG.C0.CS_WIDTH {2} \
  CONFIG.C0.DDR4_AxiAddressWidth {32} \
  CONFIG.C0.DDR4_AxiDataWidth {512} \
  CONFIG.C0.DDR4_AxiNarrowBurst {true} \
  CONFIG.C0.DDR4_AxiSelection {true} \
  CONFIG.C0.DDR4_CLKOUT0_DIVIDE {3} \
  CONFIG.C0.DDR4_CasLatency {19} \
  CONFIG.C0.DDR4_Clamshell {true} \
  CONFIG.C0.DDR4_DataMask {NO_DM_NO_DBI} \
  CONFIG.C0.DDR4_DataWidth {72} \
  CONFIG.C0.DDR4_Ecc {true} \
  CONFIG.C0.DDR4_InputClockPeriod {10000} \
  CONFIG.C0.DDR4_MemoryPart {MT40A512M16HA-075E} \
  CONFIG.C0_CLOCK_BOARD_INTERFACE {default_100mhz_clk} \
  CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram} \
  CONFIG.Debug_Signal {Enable} \
] [get_ips mig]

# Runtime Parameters
set_property -dict {
  GENERATE_SYNTH_CHECKPOINT {1}
} $mig

# Generate output products
generate_target all [get_ips mig]
