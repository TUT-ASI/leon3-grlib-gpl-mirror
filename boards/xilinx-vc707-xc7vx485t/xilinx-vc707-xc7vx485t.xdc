# --- Define and contraint system clock
create_clock -period 5.000 -name clk200 [get_ports clk200p]
set_propagated_clock clk200

# --- General Clock Domain Crossings
# N/A

# --- Global False paths
set_false_path -to   [get_ports {led[*]}]
set_false_path -from [get_ports {button[*]}]
set_false_path -from [get_ports reset]
set_false_path -from [get_ports switch*]
set_false_path -to   [get_ports switch*]

# --- Flash
# Outputs
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 1.000 [get_ports oen]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports oen]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 1.000 [get_ports writen]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports writen]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 1.000 [get_ports romsn]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports romsn]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 1.000 [get_ports adv]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports adv]

# BiDir
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 3.000 [get_ports data*]
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay 1.000 [get_ports data*]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max -add_delay 1.000 [get_ports data*]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports data*]

# --- UART
# Inputs
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 3.000 [get_ports dsurx]
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay 1.000 [get_ports dsurx]
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 3.000 [get_ports dsuctsn]
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay 1.000 [get_ports dsuctsn]

# Outputs
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 1.000 [get_ports dsutx]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports dsutx]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 1.000 [get_ports dsurtsn]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports dsurtsn]

# --- JTAG
# N/A

# --- I2C
# BiDir
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 3.000 [get_ports iic_scl*]
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay 1.000 [get_ports iic_scl*]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max -add_delay 1.000 [get_ports iic_scl*]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports iic_scl*]
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 3.000 [get_ports iic_sda*]
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay 1.000 [get_ports iic_sda*]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max -add_delay 1.000 [get_ports iic_sda*]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports iic_sda*]

# Pin and IO property
set_property PACKAGE_PIN E19 [get_ports clk200p]
set_property PACKAGE_PIN E18 [get_ports clk200n]
set_property IOSTANDARD DIFF_SSTL15 [get_ports clk200p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports clk200n]
set_property VCCAUX_IO DONTCARE [get_ports clk200p]
set_property VCCAUX_IO DONTCARE [get_ports clk200n]

set_property IOSTANDARD LVCMOS18 [get_ports reset]
set_property PACKAGE_PIN AV40 [get_ports reset]

set_property PACKAGE_PIN AM39 [get_ports {led[0]}]
set_property PACKAGE_PIN AN39 [get_ports {led[1]}]
set_property PACKAGE_PIN AR37 [get_ports {led[2]}]
set_property PACKAGE_PIN AT37 [get_ports {led[3]}]
set_property PACKAGE_PIN AR35 [get_ports {led[4]}]
set_property PACKAGE_PIN AP41 [get_ports {led[5]}]
set_property PACKAGE_PIN AP42 [get_ports {led[6]}]

set_property PACKAGE_PIN AM36 [get_ports {data[0]}]
set_property PACKAGE_PIN AN36 [get_ports {data[1]}]
set_property PACKAGE_PIN AJ36 [get_ports {data[2]}]
set_property PACKAGE_PIN AJ37 [get_ports {data[3]}]
set_property PACKAGE_PIN AK37 [get_ports {data[4]}]
set_property PACKAGE_PIN AL37 [get_ports {data[5]}]
set_property PACKAGE_PIN AN35 [get_ports {data[6]}]
set_property PACKAGE_PIN AP35 [get_ports {data[7]}]
set_property PACKAGE_PIN AM37 [get_ports {data[8]}]
set_property PACKAGE_PIN AG33 [get_ports {data[9]}]
set_property PACKAGE_PIN AH33 [get_ports {data[10]}]
set_property PACKAGE_PIN AK35 [get_ports {data[11]}]
set_property PACKAGE_PIN AL35 [get_ports {data[12]}]
set_property PACKAGE_PIN AJ31 [get_ports {data[13]}]
set_property PACKAGE_PIN AH34 [get_ports {data[14]}]
set_property PACKAGE_PIN AJ35 [get_ports {data[15]}]
set_property PACKAGE_PIN AW41 [get_ports {address[25]}]
set_property PACKAGE_PIN AW42 [get_ports {address[24]}]
set_property PACKAGE_PIN BB39 [get_ports {address[23]}]
set_property PACKAGE_PIN BA39 [get_ports {address[22]}]
set_property PACKAGE_PIN BA40 [get_ports {address[21]}]
set_property PACKAGE_PIN AT41 [get_ports {address[20]}]
set_property PACKAGE_PIN AU42 [get_ports {address[19]}]
set_property PACKAGE_PIN BA42 [get_ports {address[18]}]
set_property PACKAGE_PIN AU41 [get_ports {address[17]}]
set_property PACKAGE_PIN AV41 [get_ports {address[16]}]
set_property PACKAGE_PIN AM32 [get_ports {address[15]}]
set_property PACKAGE_PIN AM33 [get_ports {address[14]}]
set_property PACKAGE_PIN AN33 [get_ports {address[13]}]
set_property PACKAGE_PIN AL29 [get_ports {address[12]}]
set_property PACKAGE_PIN AL30 [get_ports {address[11]}]
set_property PACKAGE_PIN AH29 [get_ports {address[10]}]
set_property PACKAGE_PIN AH30 [get_ports {address[9]}]
set_property PACKAGE_PIN AJ30 [get_ports {address[8]}]
set_property PACKAGE_PIN AK30 [get_ports {address[7]}]
set_property PACKAGE_PIN AG29 [get_ports {address[6]}]
set_property PACKAGE_PIN AK28 [get_ports {address[5]}]
set_property PACKAGE_PIN AK29 [get_ports {address[4]}]
set_property PACKAGE_PIN AF30 [get_ports {address[3]}]
set_property PACKAGE_PIN AG31 [get_ports {address[2]}]
set_property PACKAGE_PIN AH28 [get_ports {address[1]}]
set_property PACKAGE_PIN AJ28 [get_ports {address[0]}]
set_property PACKAGE_PIN AY37 [get_ports adv]
set_property PACKAGE_PIN AL36 [get_ports romsn]
set_property PACKAGE_PIN BA41 [get_ports oen]
set_property PACKAGE_PIN BB41 [get_ports writen]

set_property PACKAGE_PIN AU36 [get_ports dsutx]
set_property PACKAGE_PIN AT32 [get_ports dsuctsn]
set_property PACKAGE_PIN AU33 [get_ports dsurx]
set_property PACKAGE_PIN AR34 [get_ports dsurtsn]

set_property PACKAGE_PIN AP40 [get_ports {button[0]}]
set_property PACKAGE_PIN AR40 [get_ports {button[1]}]
set_property PACKAGE_PIN AV39 [get_ports {button[2]}]
set_property PACKAGE_PIN AU38 [get_ports {button[3]}]
set_property PACKAGE_PIN AV30 [get_ports {switch[0]}]
set_property PACKAGE_PIN AY33 [get_ports {switch[1]}]
set_property PACKAGE_PIN BA31 [get_ports {switch[2]}]
set_property PACKAGE_PIN BA32 [get_ports {switch[3]}]
set_property PACKAGE_PIN AW30 [get_ports {switch[4]}]

set_property PACKAGE_PIN AT35 [get_ports iic_scl]
set_property PACKAGE_PIN AU32 [get_ports iic_sda]

set_property IOSTANDARD LVCMOS18 [get_ports data*]
set_property IOSTANDARD LVCMOS18 [get_ports address*]
set_property IOSTANDARD LVCMOS18 [get_ports adv]
set_property IOSTANDARD LVCMOS18 [get_ports romsn]
set_property IOSTANDARD LVCMOS18 [get_ports oen]
set_property IOSTANDARD LVCMOS18 [get_ports writen]

set_property IOSTANDARD LVCMOS18 [get_ports dsu*]
set_property IOSTANDARD LVCMOS18 [get_ports led*]
set_property IOSTANDARD LVCMOS18 [get_ports button*]
set_property IOSTANDARD LVCMOS18 [get_ports switch*]
set_property IOSTANDARD LVCMOS18 [get_ports iic*]

#-----------------------------------------------------------
#              USB2 / ULPI                                 -
#-----------------------------------------------------------

# Check if USB is in design  
#set usbtest [get_pins -hier *usb*?RST]
  
set_property PACKAGE_PIN AV34 [get_ports usb_refclk_opt]
set_property PACKAGE_PIN AY32 [get_ports usb_clkout]
set_property PACKAGE_PIN BB36 [get_ports usb_resetn]
set_property PACKAGE_PIN BB32 [get_ports usb_stp]
set_property PACKAGE_PIN BB33 [get_ports usb_dir]
set_property PACKAGE_PIN BA35 [get_ports usb_nxt]
set_property PACKAGE_PIN AV36 [get_ports {usb_d[0]}]
set_property PACKAGE_PIN AW36 [get_ports {usb_d[1]}]
set_property PACKAGE_PIN BA34 [get_ports {usb_d[2]}]
set_property PACKAGE_PIN BB34 [get_ports {usb_d[3]}]
set_property PACKAGE_PIN BA36 [get_ports {usb_d[4]}]
set_property PACKAGE_PIN AW35 [get_ports {usb_d[7]}]
set_property PACKAGE_PIN AY35 [get_ports {usb_d[6]}]
set_property PACKAGE_PIN AT34 [get_ports {usb_d[5]}]

set_property IOSTANDARD LVCMOS18 [get_ports usb_refclk_opt]
set_property IOSTANDARD LVCMOS18 [get_ports usb_clkout]
set_property IOSTANDARD LVCMOS18 [get_ports usb_resetn]
set_property IOSTANDARD LVCMOS18 [get_ports usb_stp]
set_property IOSTANDARD LVCMOS18 [get_ports usb_dir]
set_property IOSTANDARD LVCMOS18 [get_ports usb_nxt]
set_property IOSTANDARD LVCMOS18 [get_ports {usb_d[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {usb_d[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {usb_d[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {usb_d[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {usb_d[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {usb_d[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {usb_d[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {usb_d[5]}]

#if {![string equal $usbtest ""]} {
  # USB clock
  create_clock -period 16.000 -name clkusbout [get_ports usb_clkout]
  set_propagated_clock clkusbout

  # Inputs
  set_input_delay -clock [get_clocks clkusbout] -max 7.000 [get_ports usb_nxt]
  set_input_delay -clock [get_clocks clkusbout] -min -add_delay 1.000 [get_ports usb_nxt]
  set_input_delay -clock [get_clocks clkusbout] -max 7.000 [get_ports usb_dir]
  set_input_delay -clock [get_clocks clkusbout] -min -add_delay 1.000 [get_ports usb_dir]
  
  # Outputs
  set_output_delay -clock [get_clocks clkusbout] -max 1.000 [get_ports usb_stp]
  set_output_delay -clock [get_clocks clkusbout] -min -add_delay -1.000 [get_ports usb_stp]
  
  # BiDir
  set_input_delay -clock [get_clocks clkusbout] -max 7.000 [get_ports {usb_d[*]}]
  set_input_delay -clock [get_clocks clkusbout] -min -add_delay 1.000 [get_ports {usb_d[*]}]
  set_output_delay -clock [get_clocks clkusbout] -max -add_delay 1.000 [get_ports {usb_d[*]}]
  set_output_delay -clock [get_clocks clkusbout] -min -add_delay -1.000 [get_ports {usb_d[*]}]
  
  # False paths
  set_false_path -to [get_ports usb_resetn]
  set_false_path -from [get_clocks clkusbout] -to [get_clocks -include_generated_clocks *clk_pll_i*]
  set_false_path -from [get_clocks -include_generated_clocks *clk_pll_i*] -to [get_clocks clkusbout]
  
  # Multicycle paths
  # (places the setup check at clock edge 2 and the hold check at clock edge 2(3))
  set_multicycle_path -setup -from [get_ports usb_dir] -to [get_ports {usb_d[*]}] 2
  set_multicycle_path -hold -from [get_ports usb_dir] -to [get_ports {usb_d[*]}] 3
#}
  
#-----------------------------------------------------------
#              Ethernet / SGMII                            -
#-----------------------------------------------------------
set_property PACKAGE_PIN AH8 [get_ports gtrefclk_p]
set_property PACKAGE_PIN AH7 [get_ports gtrefclk_n]
set_property PACKAGE_PIN AN2 [get_ports txp]
set_property PACKAGE_PIN AN1 [get_ports txn]
set_property PACKAGE_PIN AM7 [get_ports rxn]
set_property PACKAGE_PIN AM8 [get_ports rxp]
set_property PACKAGE_PIN AH31 [get_ports emdc]
set_property PACKAGE_PIN AJ33 [get_ports erst]
set_property PACKAGE_PIN AK33 [get_ports emdio]
set_property PACKAGE_PIN AL31 [get_ports eint]

set_property IOSTANDARD LVCMOS18 [get_ports emdc]
set_property IOSTANDARD LVCMOS18 [get_ports erst]
set_property IOSTANDARD LVCMOS18 [get_ports emdio]
set_property IOSTANDARD LVCMOS18 [get_ports eint]

#-----------------------------------------------------------
# PCS/PMA Clock period Constraints: please do not relax    -
#-----------------------------------------------------------

create_clock -period 8.000 -name gtrefclk [get_pins -hier *ibufds_gtrefclk/O]
set_propagated_clock [get_clocks gtrefclk]

create_clock -period 16.000 -name txoutclk [get_pins eth0.sgmii0/core_wrapper/inst/transceiver_inst/gtwizard_inst/*/gtwizard_i/gt0_GTWIZARD_i/gtxe2_i/TXOUTCLK]
set_propagated_clock [get_clocks txoutclk]

# Clock period for the recovered Rx clock
create_clock -period 16.000 -name rxoutclk [get_pins eth0.sgmii0/core_wrapper/inst/transceiver_inst/gtwizard_inst/*/gtwizard_i/gt0_GTWIZARD_i/gtxe2_i/RXOUTCLK]
set_propagated_clock [get_clocks rxoutclk]

#set_false_path -from [get_clocks -include_generated_clocks *clk_pll_i*]  -to [get_clocks {gtrefclk txoutclk rxoutclk}]
set_max_delay -from [get_clocks -include_generated_clocks *clk_pll_i*] -to [get_clocks {gtrefclk rxoutclk}] 8.000
set_max_delay -from [get_clocks -include_generated_clocks *clk_pll_i*] -to [get_clocks -include_generated_clocks txoutclk] 8.000
set_max_delay -from [get_clocks gtrefclk] -to [get_clocks -include_generated_clocks *clk_pll_i*] 8.000
set_max_delay -from [get_clocks -include_generated_clocks txoutclk] -to [get_clocks -include_generated_clocks *clk_pll_i*] 8.000
set_max_delay -from [get_clocks rxoutclk] -to [get_clocks -include_generated_clocks *clk_pll_i*] 8.000

set_max_delay -from [get_clocks gtrefclk] -to [get_clocks {txoutclk rxoutclk}] 8.000
set_max_delay -from [get_clocks -include_generated_clocks txoutclk] -to [get_clocks {gtrefclk rxoutclk}] 8.000
set_max_delay -from [get_clocks rxoutclk] -to [get_clocks gtrefclk] 8.000
set_max_delay -from [get_clocks rxoutclk] -to [get_clocks -include_generated_clocks txoutclk] 8.000

#set_max_delay -from [get_clocks -include_generated_clocks *CLKOUT*] -to [get_clocks -include_generated_clocks] 8.000
#set_max_delay -from [get_clocks -include_generated_clocks] -to [get_clocks -include_generated_clocks *CLKOUT*] 8.000

#################################################

#-----------------------------------------------------------
# GT Initialization circuitry clock domain crossing
#-----------------------------------------------------------

set_false_path -to [get_pins -hier -filter { name =~ */gtwizard_inst/*/gt0_txresetfsm_i/sync_*/*D }]
set_false_path -to [get_pins -hier -filter { name =~ */gtwizard_inst/*/gt0_rxresetfsm_i/sync_*/*D }]
set_false_path -to [get_pins -hier -filter { name =~ */gtwizard_inst/*/sync_*/*D }]
#set_false_path -to [get_pins -of [get_cells -hier -filter { name =~ *gtwizard_inst/*/sync_block_gtrxreset/data_sync* }] -filter { name =~ *D }]

# false path constraints to async inputs coming directly to synchronizer
set_false_path -to [get_pins -hier -filter {name =~ *SYNC_*/data_sync*/D }]
set_false_path -to [get_pins -hier -filter {name =~ */*sync_speed_10*/data_sync*/D }]
set_false_path -to [get_pins -hier -filter {name =~ */*gen_sync_reset/reset_sync*/PRE }]
set_false_path -to [get_pins -hier -filter {name =~ *gpcs_pma_inst/MGT_RESET.RESET_INT_*/PRE }]
set_false_path -to [get_pins -hier -filter {name =~ *reset_sync*/PRE}]

#-----------------------------------------------------------
# GT Initialization circuitry clock domain crossing
#-----------------------------------------------------------

# false path constraints to async inputs coming directly to synchronizer
#set_false_path -to [get_pins -hier -filter {name =~ *SYNC_*/data_sync/D }]
set_false_path -to [get_pins -hier -filter {name =~ *gpcs_pma_inst/MGT_RESET.RESET_INT_*/PRE }]

set_false_path -to [get_pins -hier -filter {name =~ *reset_sync1/PRE }]
set_false_path -to [get_pins -hier -filter {name =~ *reset_sync2/PRE }]

#-----------------------------------------------------------
#             FMC / RGMII                                 -
#-----------------------------------------------------------

# TODO: Check if this section can be opt out when not used.
#if {![string equal $fmctest ""]} {
  set_property CLOCK_DEDICATED_ROUTE FALSE [get_pins -hier -filter {name =~ *eth1*clk125*/O}]

  # Enable internal termination resistor on LVDS 125MHz ref_clk
  set_property DIFF_TERM TRUE [get_ports ref_clk_clk_p]
  set_property DIFF_TERM TRUE [get_ports ref_clk_clk_n]

  create_clock -period 8.000 -name ref_clk_clk_p -waveform {0.000 4.000} [get_ports ref_clk_clk_p]
  create_clock -period 8.000 -name rgmii_port_0_rxc -waveform {0.000 4.000} [get_ports rgmii_port_0_rxc]
  create_clock -period 8.000 -name rgmii_port_1_rxc -waveform {0.000 4.000} [get_ports rgmii_port_1_rxc]
  create_clock -period 8.000 -name rgmii_port_2_rxc -waveform {0.000 4.000} [get_ports rgmii_port_2_rxc]
  create_clock -period 8.000 -name rgmii_port_3_rxc -waveform {0.000 4.000} [get_ports rgmii_port_3_rxc]
  create_clock -period 8.000 -name rgmii_port_4_rxc -waveform {0.000 4.000} [get_ports rgmii_port_4_rxc]
  create_clock -period 8.000 -name rgmii_port_5_rxc -waveform {0.000 4.000} [get_ports rgmii_port_5_rxc]
  create_clock -period 8.000 -name rgmii_port_6_rxc -waveform {0.000 4.000} [get_ports rgmii_port_6_rxc]
  create_clock -period 8.000 -name rgmii_port_7_rxc -waveform {0.000 4.000} [get_ports rgmii_port_7_rxc]

  set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks rgmii_port_*_rxc]
  set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks rgmii_port_*_rxc]

  set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks clk25*]
  set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks clk25*]
  set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks clk50*]
  set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks clk50*]
  set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks clk125*]
  set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks clk125*]

  set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks io_ref]
  set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks io_ref]

  set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks clkout0_1]
  set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks clkout0_1]

  set_false_path -from [get_clocks clk25*] -to   [get_clocks clk125*]
  set_false_path -to   [get_clocks clk25*] -from [get_clocks clk125*]
   
  set_false_path -from [get_clocks clk50*] -to   [get_clocks clk125*]
  set_false_path -to   [get_clocks clk50*] -from [get_clocks clk125*]
  
  set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk25]
  set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets clk125]
  set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets clk50]

  set_false_path -from [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT0]] -to [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT3]]
  set_false_path -from [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT0]] -to [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT2]]
  set_false_path -from [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT0]] -to [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]]
  set_false_path -from [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT2]] -to [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]]
  set_false_path -from [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT3]] -to [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]]
  set_false_path -from [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -to [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT3]]
  set_false_path -from [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -to [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT2]]
  set_false_path -from [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -to [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT0]]
  set_false_path -from [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -to [get_clocks -of_objects [get_pins eth0.sgmii0/sgmii0.mmcm_adv_inst/CLKOUT0]]

  # Section 4.10.2.2
  ###set_output_delay -clock [get_clocks clk25*] -max -1.0 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}]
  ###set_output_delay -clock [get_clocks clk25*] -min -2.6 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay
  ###set_output_delay -clock [get_clocks clk25*] -clock_fall -max -1.0 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay
  ###set_output_delay -clock [get_clocks clk25*] -clock_fall -min -2.6 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay
  ####set_output_delay -clock [get_clocks clk125*] -max -1.0 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}]
  ####set_output_delay -clock [get_clocks clk125*] -min -2.6 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay
  ####set_output_delay -clock [get_clocks clk125*] -clock_fall -max -1.0 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay
  ####set_output_delay -clock [get_clocks clk125*] -clock_fall -min -2.6 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay

  #}

# Define I/O standards
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_1_rd[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_0_mdio_io]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_1_rd[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ref_clk_fsel}]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_1_mdio_io]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_3_rxc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_3_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_3_rd[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_3_rd[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_1_rxc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_1_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_0_mdc]
set_property IOSTANDARD LVCMOS18 [get_ports reset_port_0]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_1_rd[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_1_rd[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ref_clk_oe}]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_1_mdc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_2_rxc]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_2_rd[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_2_rd[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_3_rd[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_3_rd[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_0_rxc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_0_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_0_rd[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_0_rd[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_0_td[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_0_td[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_1_td[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_1_td[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_1_td[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_2_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_2_rd[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_2_td[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_2_td[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_2_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_2_mdio_io]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_3_td[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_3_td[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_3_td[3]}]
set_property IOSTANDARD LVDS     [get_ports ref_clk_clk_p]
set_property IOSTANDARD LVDS     [get_ports ref_clk_clk_n]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_0_rd[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_0_rd[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_0_td[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_0_txc]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_0_td[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_0_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_1_td[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_1_txc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_1_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports reset_port_1]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_2_rd[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_2_td[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_2_txc]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_2_td[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_2_mdc]
set_property IOSTANDARD LVCMOS18 [get_ports reset_port_2]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_3_td[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_3_txc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_3_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_3_mdc]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_3_mdio_io]
set_property IOSTANDARD LVCMOS18 [get_ports reset_port_3]

set_property PACKAGE_PIN K42 [get_ports {rgmii_port_1_rd[0]}]
set_property PACKAGE_PIN J42 [get_ports mdio_io_port_0_mdio_io]
set_property PACKAGE_PIN M39 [get_ports {rgmii_port_1_rd[2]}]
set_property PACKAGE_PIN N39 [get_ports {ref_clk_fsel}]
set_property PACKAGE_PIN N40 [get_ports mdio_io_port_1_mdio_io]
set_property PACKAGE_PIN M32 [get_ports rgmii_port_3_rxc]
set_property PACKAGE_PIN L32 [get_ports rgmii_port_3_rx_ctl]
set_property PACKAGE_PIN J31 [get_ports {rgmii_port_3_rd[1]}]
set_property PACKAGE_PIN H31 [get_ports {rgmii_port_3_rd[3]}]
set_property PACKAGE_PIN J40 [get_ports rgmii_port_1_rxc]
set_property PACKAGE_PIN J41 [get_ports rgmii_port_1_rx_ctl]
set_property PACKAGE_PIN M41 [get_ports mdio_io_port_0_mdc]
set_property PACKAGE_PIN L41 [get_ports reset_port_0]
set_property PACKAGE_PIN R42 [get_ports {rgmii_port_1_rd[1]}]
set_property PACKAGE_PIN P42 [get_ports {rgmii_port_1_rd[3]}]
set_property PACKAGE_PIN H39 [get_ports {ref_clk_oe}]
set_property PACKAGE_PIN G39 [get_ports mdio_io_port_1_mdc]
set_property PACKAGE_PIN L31 [get_ports rgmii_port_2_rxc]
set_property PACKAGE_PIN P30 [get_ports {rgmii_port_2_rd[2]}]
set_property PACKAGE_PIN N31 [get_ports {rgmii_port_2_rd[3]}]
set_property PACKAGE_PIN J30 [get_ports {rgmii_port_3_rd[0]}]
set_property PACKAGE_PIN H30 [get_ports {rgmii_port_3_rd[2]}]
set_property PACKAGE_PIN K39 [get_ports rgmii_port_0_rxc]
set_property PACKAGE_PIN K40 [get_ports rgmii_port_0_rx_ctl]
set_property PACKAGE_PIN M42 [get_ports {rgmii_port_0_rd[2]}]
set_property PACKAGE_PIN L42 [get_ports {rgmii_port_0_rd[3]}]
set_property PACKAGE_PIN M37 [get_ports {rgmii_port_0_td[1]}]
set_property PACKAGE_PIN M38 [get_ports {rgmii_port_0_td[2]}]
set_property PACKAGE_PIN P40 [get_ports {rgmii_port_1_td[0]}]
set_property PACKAGE_PIN K37 [get_ports {rgmii_port_1_td[2]}]
set_property PACKAGE_PIN K38 [get_ports {rgmii_port_1_td[3]}]
set_property PACKAGE_PIN Y29 [get_ports rgmii_port_2_rx_ctl]
set_property PACKAGE_PIN Y30 [get_ports {rgmii_port_2_rd[0]}]
set_property PACKAGE_PIN R28 [get_ports {rgmii_port_2_td[1]}]
set_property PACKAGE_PIN P28 [get_ports {rgmii_port_2_td[2]}]
set_property PACKAGE_PIN K29 [get_ports rgmii_port_2_tx_ctl]
set_property PACKAGE_PIN K30 [get_ports mdio_io_port_2_mdio_io]
set_property PACKAGE_PIN T30 [get_ports {rgmii_port_3_td[0]}]
set_property PACKAGE_PIN M28 [get_ports {rgmii_port_3_td[2]}]
set_property PACKAGE_PIN M29 [get_ports {rgmii_port_3_td[3]}]
set_property PACKAGE_PIN L39 [get_ports ref_clk_clk_p]
set_property PACKAGE_PIN L40 [get_ports ref_clk_clk_n]
set_property PACKAGE_PIN P41 [get_ports {rgmii_port_0_rd[0]}]
set_property PACKAGE_PIN N41 [get_ports {rgmii_port_0_rd[1]}]
set_property PACKAGE_PIN H40 [get_ports {rgmii_port_0_td[0]}]
set_property PACKAGE_PIN H41 [get_ports rgmii_port_0_txc]
set_property PACKAGE_PIN G41 [get_ports {rgmii_port_0_td[3]}]
set_property PACKAGE_PIN G42 [get_ports rgmii_port_0_tx_ctl]
set_property PACKAGE_PIN F40 [get_ports {rgmii_port_1_td[1]}]
set_property PACKAGE_PIN F41 [get_ports rgmii_port_1_txc]
set_property PACKAGE_PIN M36 [get_ports rgmii_port_1_tx_ctl]
set_property PACKAGE_PIN L37 [get_ports reset_port_1]
set_property PACKAGE_PIN W30 [get_ports {rgmii_port_2_rd[1]}]
set_property PACKAGE_PIN W31 [get_ports {rgmii_port_2_td[0]}]
set_property PACKAGE_PIN N28 [get_ports rgmii_port_2_txc]
set_property PACKAGE_PIN N29 [get_ports {rgmii_port_2_td[3]}]
set_property PACKAGE_PIN R30 [get_ports mdio_io_port_2_mdc]
set_property PACKAGE_PIN P31 [get_ports reset_port_2]
set_property PACKAGE_PIN L29 [get_ports {rgmii_port_3_td[1]}]
set_property PACKAGE_PIN L30 [get_ports rgmii_port_3_txc]
set_property PACKAGE_PIN V30 [get_ports rgmii_port_3_tx_ctl]
set_property PACKAGE_PIN V31 [get_ports mdio_io_port_3_mdc]
set_property PACKAGE_PIN V29 [get_ports mdio_io_port_3_mdio_io]
set_property PACKAGE_PIN U29 [get_ports reset_port_3]

# Constraints for second Ethernet FMC plugged onto the HPC1 connector
# Ports are numbered 4 to 7

# Define I/O standards
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_5_rd[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_4_mdio_io]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_5_rd[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ref_clk_1_fsel[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_5_mdio_io]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_7_rxc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_7_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_7_rd[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_7_rd[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_5_rxc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_5_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_4_mdc]
set_property IOSTANDARD LVCMOS18 [get_ports reset_port_4]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_5_rd[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_5_rd[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ref_clk_1_oe[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_5_mdc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_6_rxc]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_6_rd[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_6_rd[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_7_rd[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_7_rd[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_4_rxc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_4_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_4_rd[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_4_rd[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_4_td[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_4_td[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_5_td[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_5_td[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_5_td[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_6_rx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_6_rd[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_6_td[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_6_td[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_6_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_6_mdio_io]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_7_td[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_7_td[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_7_td[3]}]
set_property IOSTANDARD LVDS [get_ports ref_clk_1_clk_p]
set_property IOSTANDARD LVDS [get_ports ref_clk_1_clk_n]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_4_rd[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_4_rd[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_4_td[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_4_txc]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_4_td[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_4_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_5_td[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_5_txc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_5_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports reset_port_5]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_6_rd[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_6_td[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_6_txc]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_6_td[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_6_mdc]
set_property IOSTANDARD LVCMOS18 [get_ports reset_port_6]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_port_7_td[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_7_txc]
set_property IOSTANDARD LVCMOS18 [get_ports rgmii_port_7_tx_ctl]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_7_mdc]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_io_port_7_mdio_io]
set_property IOSTANDARD LVCMOS18 [get_ports reset_port_7]

set_property PACKAGE_PIN AD38 [get_ports {rgmii_port_5_rd[0]}]
set_property PACKAGE_PIN AE38 [get_ports mdio_io_port_4_mdio_io]
set_property PACKAGE_PIN AB42 [get_ports {rgmii_port_5_rd[2]}]
set_property PACKAGE_PIN AB38 [get_ports {ref_clk_1_fsel[0]}]
set_property PACKAGE_PIN AB39 [get_ports mdio_io_port_5_mdio_io]
set_property PACKAGE_PIN U36  [get_ports rgmii_port_7_rxc]
set_property PACKAGE_PIN T37  [get_ports rgmii_port_7_rx_ctl]
set_property PACKAGE_PIN P32  [get_ports {rgmii_port_7_rd[1]}]
set_property PACKAGE_PIN P33  [get_ports {rgmii_port_7_rd[3]}]
set_property PACKAGE_PIN AF41 [get_ports rgmii_port_5_rxc]
set_property PACKAGE_PIN AG41 [get_ports rgmii_port_5_rx_ctl]
set_property PACKAGE_PIN AF42 [get_ports mdio_io_port_4_mdc]
set_property PACKAGE_PIN AG42 [get_ports reset_port_4]
set_property PACKAGE_PIN AJ38 [get_ports {rgmii_port_5_rd[1]}]
set_property PACKAGE_PIN AK38 [get_ports {rgmii_port_5_rd[3]}]
set_property PACKAGE_PIN W40  [get_ports {ref_clk_1_oe[0]}]
set_property PACKAGE_PIN Y40  [get_ports mdio_io_port_5_mdc]
set_property PACKAGE_PIN U37  [get_ports rgmii_port_6_rxc]
set_property PACKAGE_PIN R38  [get_ports {rgmii_port_6_rd[2]}]
set_property PACKAGE_PIN R39  [get_ports {rgmii_port_6_rd[3]}]
set_property PACKAGE_PIN N33  [get_ports {rgmii_port_7_rd[0]}]
set_property PACKAGE_PIN N34  [get_ports {rgmii_port_7_rd[2]}]
set_property PACKAGE_PIN AD40 [get_ports rgmii_port_4_rxc]
set_property PACKAGE_PIN AD41 [get_ports rgmii_port_4_rx_ctl]
set_property PACKAGE_PIN AJ42 [get_ports {rgmii_port_4_rd[2]}]
set_property PACKAGE_PIN AK42 [get_ports {rgmii_port_4_rd[3]}]
set_property PACKAGE_PIN AD42 [get_ports {rgmii_port_4_td[1]}]
set_property PACKAGE_PIN AE42 [get_ports {rgmii_port_4_td[2]}]
set_property PACKAGE_PIN AA39 [get_ports {rgmii_port_5_td[0]}]
set_property PACKAGE_PIN AJ40 [get_ports {rgmii_port_5_td[2]}]
set_property PACKAGE_PIN AJ41 [get_ports {rgmii_port_5_td[3]}]
set_property PACKAGE_PIN V33  [get_ports rgmii_port_6_rx_ctl]
set_property PACKAGE_PIN V34  [get_ports {rgmii_port_6_rd[0]}]
set_property PACKAGE_PIN W32  [get_ports {rgmii_port_6_td[1]}]
set_property PACKAGE_PIN W33  [get_ports {rgmii_port_6_td[2]}]
set_property PACKAGE_PIN R33  [get_ports rgmii_port_6_tx_ctl]
set_property PACKAGE_PIN R34  [get_ports mdio_io_port_6_mdio_io]
set_property PACKAGE_PIN W37  [get_ports {rgmii_port_7_td[0]}]
set_property PACKAGE_PIN V39  [get_ports {rgmii_port_7_td[2]}]
set_property PACKAGE_PIN V40  [get_ports {rgmii_port_7_td[3]}]
set_property PACKAGE_PIN AF39 [get_ports ref_clk_1_clk_p]
set_property PACKAGE_PIN AF40 [get_ports ref_clk_1_clk_n]
set_property PACKAGE_PIN AK39 [get_ports {rgmii_port_4_rd[0]}]
set_property PACKAGE_PIN AL39 [get_ports {rgmii_port_4_rd[1]}]
set_property PACKAGE_PIN AL41 [get_ports {rgmii_port_4_td[0]}]
set_property PACKAGE_PIN AL42 [get_ports rgmii_port_4_txc]
set_property PACKAGE_PIN AC40 [get_ports {rgmii_port_4_td[3]}]
set_property PACKAGE_PIN AC41 [get_ports rgmii_port_4_tx_ctl]
set_property PACKAGE_PIN Y42  [get_ports {rgmii_port_5_td[1]}]
set_property PACKAGE_PIN AA42 [get_ports rgmii_port_5_txc]
set_property PACKAGE_PIN AC38 [get_ports rgmii_port_5_tx_ctl]
set_property PACKAGE_PIN AC39 [get_ports reset_port_5]
set_property PACKAGE_PIN U32  [get_ports {rgmii_port_6_rd[1]}]
set_property PACKAGE_PIN U33  [get_ports {rgmii_port_6_td[0]}]
set_property PACKAGE_PIN P35  [get_ports rgmii_port_6_txc]
set_property PACKAGE_PIN P36  [get_ports {rgmii_port_6_td[3]}]
set_property PACKAGE_PIN U34  [get_ports mdio_io_port_6_mdc]
set_property PACKAGE_PIN T35  [get_ports reset_port_6]
set_property PACKAGE_PIN V35  [get_ports {rgmii_port_7_td[1]}]
set_property PACKAGE_PIN V36  [get_ports rgmii_port_7_txc]
set_property PACKAGE_PIN T32  [get_ports rgmii_port_7_tx_ctl]
set_property PACKAGE_PIN R32  [get_ports mdio_io_port_7_mdc]
set_property PACKAGE_PIN P37  [get_ports mdio_io_port_7_mdio_io]
set_property PACKAGE_PIN P38  [get_ports reset_port_7]

#-----------------------------------------------------------
# GRETH
#-----------------------------------------------------------

# N.a (See above)

#-----------------------------------------------------------
#                  CAN                                     -
#-----------------------------------------------------------

# Check if USB is in design  
set cantest [get_pins -hier *can*?RST]

set_property PACKAGE_PIN AF35 [get_ports {can_rxd[0]}]
set_property PACKAGE_PIN AF36 [get_ports {can_txd[0]}]

set_property IOSTANDARD LVCMOS18 [get_ports {can_rxd[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {can_txd[0]}]

#if {![string equal $cantest ""]} {
  # Inputs
  set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 3.000 [get_ports can_rxd]
  set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay 1.000 [get_ports can_rxd]

  # Outputs
  set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 1.000 [get_ports can_txd]
  set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports can_txd]
#}

#-----------------------------------------------------------
#                  SPI                                     -
#-----------------------------------------------------------

set_property PACKAGE_PIN AE37 [get_ports spi_data_out]
set_property PACKAGE_PIN AF37 [get_ports spi_data_in]
set_property PACKAGE_PIN AD36 [get_ports spi_clk]
set_property PACKAGE_PIN AD37 [get_ports spi_data_cs_b]

set_property IOSTANDARD LVCMOS18 [get_ports spi_data_out]
set_property IOSTANDARD LVCMOS18 [get_ports spi_data_in]
set_property IOSTANDARD LVCMOS18 [get_ports spi_clk]
set_property IOSTANDARD LVCMOS18 [get_ports spi_data_cs_b]

# Inputs
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 3.000 [get_ports spi_data_out]
set_input_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay 1.000 [get_ports spi_data_out]

# Outputs
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 1.000 [get_ports spi_data_in]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports spi_data_in]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 1.000 [get_ports spi_clk]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports spi_clk]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -max 1.000 [get_ports spi_data_cs_b]
set_output_delay -clock [get_clocks -include_generated_clocks *clkfb*] -min -add_delay -1.000 [get_ports spi_data_cs_b]


#-----------------------------------------------------------
#              MIG                                         -
#-----------------------------------------------------------

#set migtest [get_pins -hier *mig*rst*]
#if {![string equal $migtest ""]} {
# Bank: 39 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[0]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[0]}]
set_property PACKAGE_PIN N14 [get_ports {ddr3_dq[0]}]

# Bank: 39 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[1]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[1]}]
set_property PACKAGE_PIN N13 [get_ports {ddr3_dq[1]}]

# Bank: 39 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[2]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[2]}]
set_property PACKAGE_PIN L14 [get_ports {ddr3_dq[2]}]

# Bank: 39 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[3]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[3]}]
set_property PACKAGE_PIN M14 [get_ports {ddr3_dq[3]}]

# Bank: 39 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[4]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[4]}]
set_property PACKAGE_PIN M12 [get_ports {ddr3_dq[4]}]

# Bank: 39 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[5]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[5]}]
set_property PACKAGE_PIN N15 [get_ports {ddr3_dq[5]}]

# Bank: 39 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[6]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[6]}]
set_property PACKAGE_PIN M11 [get_ports {ddr3_dq[6]}]

# Bank: 39 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[7]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[7]}]
set_property PACKAGE_PIN L12 [get_ports {ddr3_dq[7]}]

# Bank: 39 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[8]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[8]}]
set_property PACKAGE_PIN K14 [get_ports {ddr3_dq[8]}]

# Bank: 39 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[9]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[9]}]
set_property PACKAGE_PIN K13 [get_ports {ddr3_dq[9]}]

# Bank: 39 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[10]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[10]}]
set_property PACKAGE_PIN H13 [get_ports {ddr3_dq[10]}]

# Bank: 39 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[11]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[11]}]
set_property PACKAGE_PIN J13 [get_ports {ddr3_dq[11]}]

# Bank: 39 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[12]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[12]}]
set_property PACKAGE_PIN L16 [get_ports {ddr3_dq[12]}]

# Bank: 39 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[13]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[13]}]
set_property PACKAGE_PIN L15 [get_ports {ddr3_dq[13]}]

# Bank: 39 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[14]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[14]}]
set_property PACKAGE_PIN H14 [get_ports {ddr3_dq[14]}]

# Bank: 39 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[15]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[15]}]
set_property PACKAGE_PIN J15 [get_ports {ddr3_dq[15]}]

# Bank: 39 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[16]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[16]}]
set_property PACKAGE_PIN E15 [get_ports {ddr3_dq[16]}]

# Bank: 39 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[17]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[17]}]
set_property PACKAGE_PIN E13 [get_ports {ddr3_dq[17]}]

# Bank: 39 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[18]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[18]}]
set_property PACKAGE_PIN F15 [get_ports {ddr3_dq[18]}]

# Bank: 39 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[19]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[19]}]
set_property PACKAGE_PIN E14 [get_ports {ddr3_dq[19]}]

# Bank: 39 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[20]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[20]}]
set_property PACKAGE_PIN G13 [get_ports {ddr3_dq[20]}]

# Bank: 39 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[21]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[21]}]
set_property PACKAGE_PIN G12 [get_ports {ddr3_dq[21]}]

# Bank: 39 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[22]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[22]}]
set_property PACKAGE_PIN F14 [get_ports {ddr3_dq[22]}]

# Bank: 39 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[23]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[23]}]
set_property PACKAGE_PIN G14 [get_ports {ddr3_dq[23]}]

# Bank: 39 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[24]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[24]}]
set_property PACKAGE_PIN B14 [get_ports {ddr3_dq[24]}]

# Bank: 39 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[25]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[25]}]
set_property PACKAGE_PIN C13 [get_ports {ddr3_dq[25]}]

# Bank: 39 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[26]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[26]}]
set_property PACKAGE_PIN B16 [get_ports {ddr3_dq[26]}]

# Bank: 39 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[27]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[27]}]
set_property PACKAGE_PIN D15 [get_ports {ddr3_dq[27]}]

# Bank: 39 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[28]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[28]}]
set_property PACKAGE_PIN D13 [get_ports {ddr3_dq[28]}]

# Bank: 39 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[29]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[29]}]
set_property PACKAGE_PIN E12 [get_ports {ddr3_dq[29]}]

# Bank: 39 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[30]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[30]}]
set_property PACKAGE_PIN C16 [get_ports {ddr3_dq[30]}]

# Bank: 39 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[31]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[31]}]
set_property PACKAGE_PIN D16 [get_ports {ddr3_dq[31]}]

# Bank: 37 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[32]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[32]}]
set_property PACKAGE_PIN A24 [get_ports {ddr3_dq[32]}]

# Bank: 37 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[33]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[33]}]
set_property PACKAGE_PIN B23 [get_ports {ddr3_dq[33]}]

# Bank: 37 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[34]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[34]}]
set_property PACKAGE_PIN B27 [get_ports {ddr3_dq[34]}]

# Bank: 37 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[35]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[35]}]
set_property PACKAGE_PIN B26 [get_ports {ddr3_dq[35]}]

# Bank: 37 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[36]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[36]}]
set_property PACKAGE_PIN A22 [get_ports {ddr3_dq[36]}]

# Bank: 37 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[37]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[37]}]
set_property PACKAGE_PIN B22 [get_ports {ddr3_dq[37]}]

# Bank: 37 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[38]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[38]}]
set_property PACKAGE_PIN A25 [get_ports {ddr3_dq[38]}]

# Bank: 37 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dq[39]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[39]}]
set_property PACKAGE_PIN C24 [get_ports {ddr3_dq[39]}]

# Bank: 37 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[40]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[40]}]
set_property PACKAGE_PIN E24 [get_ports {ddr3_dq[40]}]

# Bank: 37 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[41]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[41]}]
set_property PACKAGE_PIN D23 [get_ports {ddr3_dq[41]}]

# Bank: 37 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[42]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[42]}]
set_property PACKAGE_PIN D26 [get_ports {ddr3_dq[42]}]

# Bank: 37 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[43]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[43]}]
set_property PACKAGE_PIN C25 [get_ports {ddr3_dq[43]}]

# Bank: 37 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[44]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[44]}]
set_property PACKAGE_PIN E23 [get_ports {ddr3_dq[44]}]

# Bank: 37 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[45]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[45]}]
set_property PACKAGE_PIN D22 [get_ports {ddr3_dq[45]}]

# Bank: 37 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[46]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[46]}]
set_property PACKAGE_PIN F22 [get_ports {ddr3_dq[46]}]

# Bank: 37 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dq[47]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[47]}]
set_property PACKAGE_PIN E22 [get_ports {ddr3_dq[47]}]

# Bank: 37 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[48]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[48]}]
set_property PACKAGE_PIN A30 [get_ports {ddr3_dq[48]}]

# Bank: 37 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[49]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[49]}]
set_property PACKAGE_PIN D27 [get_ports {ddr3_dq[49]}]

# Bank: 37 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[50]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[50]}]
set_property PACKAGE_PIN A29 [get_ports {ddr3_dq[50]}]

# Bank: 37 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[51]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[51]}]
set_property PACKAGE_PIN C28 [get_ports {ddr3_dq[51]}]

# Bank: 37 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[52]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[52]}]
set_property PACKAGE_PIN D28 [get_ports {ddr3_dq[52]}]

# Bank: 37 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[53]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[53]}]
set_property PACKAGE_PIN B31 [get_ports {ddr3_dq[53]}]

# Bank: 37 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[54]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[54]}]
set_property PACKAGE_PIN A31 [get_ports {ddr3_dq[54]}]

# Bank: 37 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dq[55]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[55]}]
set_property PACKAGE_PIN A32 [get_ports {ddr3_dq[55]}]

# Bank: 37 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[56]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[56]}]
set_property PACKAGE_PIN E30 [get_ports {ddr3_dq[56]}]

# Bank: 37 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[57]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[57]}]
set_property PACKAGE_PIN F29 [get_ports {ddr3_dq[57]}]

# Bank: 37 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[58]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[58]}]
set_property PACKAGE_PIN F30 [get_ports {ddr3_dq[58]}]

# Bank: 37 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[59]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[59]}]
set_property PACKAGE_PIN F27 [get_ports {ddr3_dq[59]}]

# Bank: 37 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[60]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[60]}]
set_property PACKAGE_PIN C30 [get_ports {ddr3_dq[60]}]

# Bank: 37 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[61]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[61]}]
set_property PACKAGE_PIN E29 [get_ports {ddr3_dq[61]}]

# Bank: 37 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[62]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[62]}]
set_property PACKAGE_PIN F26 [get_ports {ddr3_dq[62]}]

# Bank: 37 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dq[63]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[63]}]
set_property PACKAGE_PIN D30 [get_ports {ddr3_dq[63]}]

# Bank: 38 - Byte T0
set_property SLEW FAST [get_ports {ddr3_addr[13]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[13]}]
set_property PACKAGE_PIN A21 [get_ports {ddr3_addr[13]}]

# Bank: 38 - Byte T0
set_property SLEW FAST [get_ports {ddr3_addr[12]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[12]}]
set_property PACKAGE_PIN A15 [get_ports {ddr3_addr[12]}]

# Bank: 38 - Byte T0
set_property SLEW FAST [get_ports {ddr3_addr[11]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[11]}]
set_property PACKAGE_PIN B17 [get_ports {ddr3_addr[11]}]

# Bank: 38 - Byte T0
set_property SLEW FAST [get_ports {ddr3_addr[10]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[10]}]
set_property PACKAGE_PIN B21 [get_ports {ddr3_addr[10]}]

# Bank: 38 - Byte T0
set_property SLEW FAST [get_ports {ddr3_addr[9]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[9]}]
set_property PACKAGE_PIN C19 [get_ports {ddr3_addr[9]}]

# Bank: 38 - Byte T1
set_property SLEW FAST [get_ports {ddr3_addr[8]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[8]}]
set_property PACKAGE_PIN D17 [get_ports {ddr3_addr[8]}]

# Bank: 38 - Byte T0
set_property SLEW FAST [get_ports {ddr3_addr[7]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[7]}]
set_property PACKAGE_PIN C18 [get_ports {ddr3_addr[7]}]

# Bank: 38 - Byte T1
set_property SLEW FAST [get_ports {ddr3_addr[6]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[6]}]
set_property PACKAGE_PIN D20 [get_ports {ddr3_addr[6]}]

# Bank: 38 - Byte T0
set_property SLEW FAST [get_ports {ddr3_addr[5]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[5]}]
set_property PACKAGE_PIN A16 [get_ports {ddr3_addr[5]}]

# Bank: 38 - Byte T0
set_property SLEW FAST [get_ports {ddr3_addr[4]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[4]}]
set_property PACKAGE_PIN A17 [get_ports {ddr3_addr[4]}]

# Bank: 38 - Byte T0
set_property SLEW FAST [get_ports {ddr3_addr[3]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[3]}]
set_property PACKAGE_PIN A19 [get_ports {ddr3_addr[3]}]

# Bank: 38 - Byte T1
set_property SLEW FAST [get_ports {ddr3_addr[2]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[2]}]
set_property PACKAGE_PIN C20 [get_ports {ddr3_addr[2]}]

# Bank: 38 - Byte T0
set_property SLEW FAST [get_ports {ddr3_addr[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[1]}]
set_property PACKAGE_PIN B19 [get_ports {ddr3_addr[1]}]

# Bank: 38 - Byte T0
set_property SLEW FAST [get_ports {ddr3_addr[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[0]}]
set_property PACKAGE_PIN A20 [get_ports {ddr3_addr[0]}]

# Bank: 38 - Byte T1
set_property SLEW FAST [get_ports {ddr3_ba[2]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[2]}]
set_property PACKAGE_PIN D18 [get_ports {ddr3_ba[2]}]

# Bank: 38 - Byte T1
set_property SLEW FAST [get_ports {ddr3_ba[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[1]}]
set_property PACKAGE_PIN C21 [get_ports {ddr3_ba[1]}]

# Bank: 38 - Byte T1
set_property SLEW FAST [get_ports {ddr3_ba[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[0]}]
set_property PACKAGE_PIN D21 [get_ports {ddr3_ba[0]}]

# Bank: 38 - Byte T2
set_property SLEW FAST [get_ports ddr3_ras_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_ras_n]
set_property PACKAGE_PIN E20 [get_ports ddr3_ras_n]

# Bank: 38 - Byte T2
set_property SLEW FAST [get_ports ddr3_cas_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_cas_n]
set_property PACKAGE_PIN K17 [get_ports ddr3_cas_n]

# Bank: 38 - Byte T2
set_property SLEW FAST [get_ports ddr3_we_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_we_n]
set_property PACKAGE_PIN F20 [get_ports ddr3_we_n]

# Bank: 37 - Byte T2
set_property SLEW FAST [get_ports ddr3_reset_n]
set_property IOSTANDARD LVCMOS15 [get_ports ddr3_reset_n]
set_property PACKAGE_PIN C29 [get_ports ddr3_reset_n]

# Bank: 38 - Byte T2
set_property SLEW FAST [get_ports {ddr3_cke[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_cke[0]}]
set_property PACKAGE_PIN K19 [get_ports {ddr3_cke[0]}]

# Bank: 38 - Byte T2
set_property SLEW FAST [get_ports {ddr3_odt[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_odt[0]}]
set_property PACKAGE_PIN H20 [get_ports {ddr3_odt[0]}]

# Bank: 38 - Byte T2
set_property SLEW FAST [get_ports {ddr3_cs_n[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_cs_n[0]}]
set_property PACKAGE_PIN J17 [get_ports {ddr3_cs_n[0]}]

# Bank: 39 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dm[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[0]}]
set_property PACKAGE_PIN M13 [get_ports {ddr3_dm[0]}]

# Bank: 39 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dm[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[1]}]
set_property PACKAGE_PIN K15 [get_ports {ddr3_dm[1]}]

# Bank: 39 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dm[2]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[2]}]
set_property PACKAGE_PIN F12 [get_ports {ddr3_dm[2]}]

# Bank: 39 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dm[3]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[3]}]
set_property PACKAGE_PIN A14 [get_ports {ddr3_dm[3]}]

# Bank: 37 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dm[4]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[4]}]
set_property PACKAGE_PIN C23 [get_ports {ddr3_dm[4]}]

# Bank: 37 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dm[5]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[5]}]
set_property PACKAGE_PIN D25 [get_ports {ddr3_dm[5]}]

# Bank: 37 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dm[6]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[6]}]
set_property PACKAGE_PIN C31 [get_ports {ddr3_dm[6]}]

# Bank: 37 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dm[7]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[7]}]
set_property PACKAGE_PIN F31 [get_ports {ddr3_dm[7]}]

# Bank: 39 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dqs_p[0]}]
set_property SLEW FAST [get_ports {ddr3_dqs_n[0]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_p[0]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_n[0]}]
set_property PACKAGE_PIN M16 [get_ports {ddr3_dqs_n[0]}]

# Bank: 39 - Byte T3

# Bank: 39 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dqs_p[1]}]
set_property SLEW FAST [get_ports {ddr3_dqs_n[1]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_p[1]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_n[1]}]
set_property PACKAGE_PIN J12 [get_ports {ddr3_dqs_n[1]}]

# Bank: 39 - Byte T2

# Bank: 39 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dqs_p[2]}]
set_property SLEW FAST [get_ports {ddr3_dqs_n[2]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_p[2]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_n[2]}]
set_property PACKAGE_PIN G16 [get_ports {ddr3_dqs_n[2]}]

# Bank: 39 - Byte T1

# Bank: 39 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dqs_p[3]}]
set_property SLEW FAST [get_ports {ddr3_dqs_n[3]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_p[3]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_n[3]}]
set_property PACKAGE_PIN C14 [get_ports {ddr3_dqs_n[3]}]

# Bank: 39 - Byte T0

# Bank: 37 - Byte T0
set_property SLEW FAST [get_ports {ddr3_dqs_p[4]}]
set_property SLEW FAST [get_ports {ddr3_dqs_n[4]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_p[4]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_n[4]}]
set_property PACKAGE_PIN A27 [get_ports {ddr3_dqs_n[4]}]

# Bank: 37 - Byte T0

# Bank: 37 - Byte T1
set_property SLEW FAST [get_ports {ddr3_dqs_p[5]}]
set_property SLEW FAST [get_ports {ddr3_dqs_n[5]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_p[5]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_n[5]}]
set_property PACKAGE_PIN E25 [get_ports {ddr3_dqs_n[5]}]

# Bank: 37 - Byte T1

# Bank: 37 - Byte T2
set_property SLEW FAST [get_ports {ddr3_dqs_p[6]}]
set_property SLEW FAST [get_ports {ddr3_dqs_n[6]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_p[6]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_n[6]}]
set_property PACKAGE_PIN B29 [get_ports {ddr3_dqs_n[6]}]

# Bank: 37 - Byte T2

# Bank: 37 - Byte T3
set_property SLEW FAST [get_ports {ddr3_dqs_p[7]}]
set_property SLEW FAST [get_ports {ddr3_dqs_n[7]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_p[7]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_n[7]}]
set_property PACKAGE_PIN E28 [get_ports {ddr3_dqs_n[7]}]

# Bank: 37 - Byte T3

# Bank: 38 - Byte T2
set_property SLEW FAST [get_ports {ddr3_ck_p[0]}]
set_property SLEW FAST [get_ports {ddr3_ck_n[0]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_ck_p[0]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_ck_n[0]}]
set_property PACKAGE_PIN G18 [get_ports {ddr3_ck_n[0]}]

# Bank: 38 - Byte T2
#}

