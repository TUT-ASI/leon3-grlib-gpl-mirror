# TCL Script for Vivado DDR4 MIG (mig)

set mig [create_ip -name ddr4 -vendor xilinx.com -library ip -module_name mig]

set_property -dict { 
  CONFIG.C0.DDR4_TimePeriod {833}
  CONFIG.C0.DDR4_InputClockPeriod {13328}
  CONFIG.C0.DDR4_Specify_MandD {true}
  CONFIG.C0.DDR4_CLKFBOUT_MULT {4}
  CONFIG.C0.DDR4_CLKOUT0_DIVIDE {4}
  CONFIG.C0.DDR4_MemoryPart {MT40A256M16GE-075E}
  CONFIG.C0.DDR4_DataWidth {16}
  CONFIG.C0.DDR4_AxiSelection {true}
  CONFIG.C0.DDR4_CasLatency {17}
  CONFIG.C0.DDR4_CasWriteLatency {12}
  CONFIG.C0.DDR4_AxiDataWidth {128}
  CONFIG.C0.DDR4_AxiNarrowBurst {true}
  CONFIG.C0.DDR4_AxiAddressWidth {29}
  CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100}
  CONFIG.Debug_Signal {Enable}
  CONFIG.C0.BANK_GROUP_WIDTH {1}
} [get_ips mig]

# Generate output products
generate_target all [get_ips mig]

