# Define and contraint system clock
create_clock -period 5.000 -name clk200 [get_ports clk200p]
set_propagated_clock [get_clocks clk200]

# --- Clock Domain Crossings

# --- False paths
set_false_path -to   [get_ports {led[*]}]
set_false_path -from [get_ports {button[*]}]
set_false_path -from [get_ports reset]
set_false_path -from [get_ports switch*]

# --- SPI FLASH
set_input_delay   -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 3.000 [get_ports spi_sel_n]
#set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 1.000 [get_ports spi_clk  ]
set_input_delay   -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 3.000 [get_ports spi_miso ]
set_output_delay  -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 1.000 [get_ports spi_mosi ]

# --- SDCARD FLASH
set_input_delay  -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 3.000 [get_ports sdcard_spi_cs_b ]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 1.000 [get_ports sdcard_spi_clk  ]
set_input_delay  -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 2.000 [get_ports sdcard_spi_miso ]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 1.000 [get_ports sdcard_spi_mosi ]

# --- UART
# Inputs
set_input_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 3.000 [get_ports dsurx]
set_input_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -min -add_delay 1.000 [get_ports dsurx]
set_input_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 3.000 [get_ports dsuctsn]
set_input_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -min -add_delay 1.000 [get_ports dsuctsn]

# Outputs
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 1.000 [get_ports dsutx]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -min -add_delay -1.000 [get_ports dsutx]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 1.000 [get_ports dsurtsn]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -min -add_delay -1.000 [get_ports dsurtsn]

# --- JTAG
# N/A

# --- I2C
# BiDir
set_input_delay  -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 3.000             [get_ports iic_scl*]
set_input_delay  -clock [get_clocks -include_generated_clocks CLKFBOUT] -min -add_delay 1.000  [get_ports iic_scl*]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -max -add_delay 1.000  [get_ports iic_scl*]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -min -add_delay -1.000 [get_ports iic_scl*]
set_input_delay  -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 3.000             [get_ports iic_sda*]
set_input_delay  -clock [get_clocks -include_generated_clocks CLKFBOUT] -min -add_delay 1.000  [get_ports iic_sda*]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -max -add_delay 1.000  [get_ports iic_sda*]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -min -add_delay -1.000 [get_ports iic_sda*]

#-----------------------------------------------------------
#              Ethernet / GMII                            -
#-----------------------------------------------------------

# The RGMII receive interface requirement allows a 1ns setup and 1ns hold - this is met but only just so constraints are relaxed
#set_input_delay -clock [get_clocks ac701_ethernet_rgmii_rgmii_rx_clk] -max -1.5 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
#set_input_delay -clock [get_clocks ac701_ethernet_rgmii_rgmii_rx_clk] -min -2.8 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
#set_input_delay -clock [get_clocks ac701_ethernet_rgmii_rgmii_rx_clk] -clock_fall -max -1.5 -add_delay [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
#set_input_delay -clock [get_clocks ac701_ethernet_rgmii_rgmii_rx_clk] -clock_fall -min -2.8 -add_delay [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]

# the following properties can be adjusted if requried to adjuct the IO timing
# the value shown is the default used by the IP
# increasing this value will improve the hold timing but will also add jitter.
#set_property IDELAY_VALUE 12 [get_cells {trimac_fifo_block/trimac_sup_block/tri_mode_ethernet_mac_i/*/rgmii_interface/delay_rgmii_rx* trimac_fifo_block/trimac_sup_block/tri_mode_ethernet_mac_i/*/rgmii_interface/rxdata_bus[*].delay_rgmii_rx*}]

set_property IOSTANDARD LVCMOS18 [get_ports phy_*]
set_property IOSTANDARD LVDS_25  [get_ports gtrefclk_*]

set_property PACKAGE_PIN AA13 [get_ports gtrefclk_p]
set_property PACKAGE_PIN AB13 [get_ports gtrefclk_n]

set_property PACKAGE_PIN U22 [get_ports phy_txclk]
set_property PACKAGE_PIN T17 [get_ports {phy_txd[3]}]
set_property PACKAGE_PIN T18 [get_ports {phy_txd[2]}]
set_property PACKAGE_PIN U15 [get_ports {phy_txd[1]}]
set_property PACKAGE_PIN U16 [get_ports {phy_txd[0]}]
set_property PACKAGE_PIN T15 [get_ports phy_txctl_txen]

set_property PACKAGE_PIN V14 [get_ports {phy_rxd[3]}]
set_property PACKAGE_PIN V16 [get_ports {phy_rxd[2]}]
set_property PACKAGE_PIN V17 [get_ports {phy_rxd[1]}]
set_property PACKAGE_PIN U17 [get_ports {phy_rxd[0]}]
set_property PACKAGE_PIN U14 [get_ports phy_rxctl_rxdv]
set_property PACKAGE_PIN U21 [get_ports phy_rxclk]

set_property PACKAGE_PIN V18 [get_ports phy_reset]

set_property PACKAGE_PIN T14 [get_ports phy_mdio]
set_property PACKAGE_PIN W18 [get_ports phy_mdc]

# Clock select
# Should be set to constant '0' to get 125Mhz GTX clock
set_property PACKAGE_PIN B26     [get_ports {sfp_clock_mux[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {sfp_clock_mux[0]}]
set_property PACKAGE_PIN C24     [get_ports {sfp_clock_mux[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {sfp_clock_mux[1]}]

# The following are required to maximise setup/hold
set_property SLEW FAST [get_ports phy_tx*]

create_clock -period 8.000 -name phy_rxclk [get_ports phy_rxclk]
set_propagated_clock [get_clocks phy_rxclk]

#create_clock -period 8.000 -name phy_txclk [get_pins eth0.gtrefclk_pad/xcv.u0/*/O]
create_clock -period 8.000 -name phy_txclk [get_pins eth0.ibufds_gtrefclk/O]
set_propagated_clock [get_clocks phy_txclk]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of [get_pins eth0.ibufds_gtrefclk/O]]

# CDC
set_max_delay -datapath_only -from [all_registers -clock [get_clocks -include_generated_clocks clk200]    ] -to [all_registers -clock [get_clocks phy_rxclk]                           ] 8.000
set_max_delay -datapath_only -from [all_registers -clock [get_clocks -include_generated_clocks clk200]    ] -to [all_registers -clock [get_clocks -include_generated_clocks phy_txclk] ] 8.000
set_max_delay -datapath_only -from [all_registers -clock [get_clocks phy_rxclk]                           ] -to [all_registers -clock [get_clocks -include_generated_clocks clk200]    ] 8.000
set_max_delay -datapath_only -from [all_registers -clock [get_clocks -include_generated_clocks phy_txclk]]  -to [all_registers -clock [get_clocks -include_generated_clocks clk200]    ] 8.000

#set_false_path -from [get_clocks {CLKOUT0_1}] -to [get_clocks {CLKOUT1_1}]
#set_false_path -from [get_clocks {CLKOUT0_1}] -to [get_clocks {CLKOUT1_1}]

# Output MUX 
# Data and Control
## set_false_path -from [get_clocks -include_generated_clocks clk200] -through [get_ports phy_tx*] -to [get_clocks -include_generated_clocks phy_txclk]
## set_false_path -from [get_clocks -include_generated_clocks phy_txclk] -through [get_ports phy_tx*] -to [get_clocks -include_generated_clocks clk200]

# Outputs
#set_output_delay -clock [get_clocks -include_generated_clocks phy_txclk] -max 2.000 [get_ports phy_txd[*]]
#set_output_delay -clock [get_clocks -include_generated_clocks phy_txclk] -min 1.000 [get_ports phy_txd[*]]
#set_output_delay -clock [get_clocks -include_generated_clocks phy_txclk] -max 2.000 [get_ports phy_txd[*]] -add_delay -clock_fall
#set_output_delay -clock [get_clocks -include_generated_clocks phy_txclk] -min 1.000 [get_ports phy_txd[*]] -add_delay -clock_fall

#set_output_delay -clock [get_clocks -include_generated_clocks phy_txclk] -max  2.000 [get_ports phy_txctl_txen]
#set_output_delay -clock [get_clocks -include_generated_clocks phy_txclk] -min 1.000 [get_ports phy_txctl_txen]
#set_output_delay -clock [get_clocks -include_generated_clocks phy_txclk] -max 2.000 [get_ports phy_txctl_txen] -add_delay -clock_fall
#set_output_delay -clock [get_clocks -include_generated_clocks phy_txclk] -min 1.000 [get_ports phy_txctl_txen] -add_delay -clock_fall

#output timing for rgmii - derated slightly due to pessimism in the tools
###create_generated_clock -name rgmii_tx_clk -divide_by 1 -source [get_pins eth0.rgmii0/*rgmii_tx_clk/*/*/C] [get_ports phy_txclk]

set_output_delay 0.75 -max -clock [get_clocks rgmii_tx_clk] [get_ports {phy_txd[*] phy_txctl_txen}]
set_output_delay -0.7 -min -clock [get_clocks rgmii_tx_clk] [get_ports {phy_txd[*] phy_txctl_txen}]
set_output_delay 0.75 -max -clock [get_clocks rgmii_tx_clk] [get_ports {phy_txd[*] phy_txctl_txen}] -clock_fall -add_delay
set_output_delay -0.7 -min -clock [get_clocks rgmii_tx_clk] [get_ports {phy_txd[*] phy_txctl_txen}] -clock_fall -add_delay


# Inputs
set_input_delay -clock [get_clocks phy_rxclk] -max 1.000 [get_ports {phy_rxd[*] phy_rxctl_rxdv}]
set_input_delay -clock [get_clocks phy_rxclk] -min 0.100 [get_ports {phy_rxd[*] phy_rxctl_rxdv}]
set_input_delay -clock [get_clocks phy_rxclk] -max 1.000 [get_ports {phy_rxd[*] phy_rxctl_rxdv}] -add_delay -clock_fall
set_input_delay -clock [get_clocks phy_rxclk] -min 0.100 [get_ports {phy_rxd[*] phy_rxctl_rxdv}] -add_delay -clock_fall

# False paths
set_false_path -to [get_ports phy_reset]

# MDIO BiDir
set_input_delay -clock  [get_clocks -include_generated_clocks CLKFBOUT] -max 5.000 [get_ports phy_mdio]
set_input_delay -clock  [get_clocks -include_generated_clocks CLKFBOUT] -min -add_delay 1.000 [get_ports phy_mdio]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -max -add_delay 1.000 [get_ports phy_mdio]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -min -add_delay -1.000 [get_ports phy_mdio]

# MDIO - Outputs
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -max 1.000 [get_ports phy_mdc]
set_output_delay -clock [get_clocks -include_generated_clocks CLKFBOUT] -min -add_delay -1.000 [get_ports phy_mdc]

# apply the same IDELAY_VALUE to all GMII RX inputs
#set_property IDELAY_VALUE 20 [get_cells {eth0.delay* eth0.rgmii*.delay*}]

# Group IODELAY and IDELAYCTRL components to aid placement
set_property IODELAY_GROUP AC701_ethernet_rgmii_grp1 [get_cells {eth0.delay* eth0.rgmii*.delay*}]
set_property IODELAY_GROUP AC701_ethernet_rgmii_grp1 [get_cells {eth0.dlyctrl0}]

#-----------------------------------------------------------
#             FMC / RGMII                                 -
#-----------------------------------------------------------
## get_clocks
##   clk200 phy_rxclk phy_txclk pll_clkfbout freq_refclk mem_refclk 
### sync_pulse pll_clk3_out PLLE2_ADV0_CLKFB_0 clk125_nobuf_0 clk25_nobuf_0  io_ref_nobuf_0 
### CLKFBIN clk_nobuf ref_clk_clk_p rgmii_port_0_rxc rgmii_port_1_rxc rgmii_port_2_rxc rgmii_port_3_rxc

  # Group IODELAY and IDELAYCTRL components to aid placement
  set_property IODELAY_GROUP AC701_ethernet_rgmii_grp1 [get_cells {eth1.*delay_rgmii* eth1.*.*delay_rgmii* eth1.*.*.*delay_rgmii*}]
  
  #####set_property CLOCK_DEDICATED_ROUTE FALSE [get_pins -hier -filter {name =~ *eth1*clk125*/O}]

  # Enable internal termination resistor on LVDS 125MHz ref_clk
  set_property DIFF_TERM TRUE [get_ports ref_clk_clk_p]
  set_property DIFF_TERM TRUE [get_ports ref_clk_clk_n]

  create_clock -period 8.000 -name ref_clk_clk_p -waveform {0.000 4.000} [get_ports ref_clk_clk_p]
  create_clock -period 8.000 -name rgmii_port_0_rxc -waveform {0.000 4.000} [get_ports rgmii_port_0_rxc]
  create_clock -period 8.000 -name rgmii_port_1_rxc -waveform {0.000 4.000} [get_ports rgmii_port_1_rxc]
  create_clock -period 8.000 -name rgmii_port_2_rxc -waveform {0.000 4.000} [get_ports rgmii_port_2_rxc]
  create_clock -period 8.000 -name rgmii_port_3_rxc -waveform {0.000 4.000} [get_ports rgmii_port_3_rxc]

  set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks rgmii_port_*_rxc]
  set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks rgmii_port_*_rxc]

  set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks clk25*]
  set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks clk25*]
  set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks clk50*]
  set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks clk50*]
  set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks clk125*]
  set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks clk125*]

  set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks io_ref*]
  set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks io_ref*]

  ##set_false_path -from [get_clocks clk_pll_i*] -to   [get_clocks clkout0_1]
  ##set_false_path -to   [get_clocks clk_pll_i*] -from [get_clocks clkout0_1]

  set_false_path -from [get_clocks clk25*] -to   [get_clocks clk125*]
  set_false_path -to   [get_clocks clk25*] -from [get_clocks clk125*]
   
  ###set_false_path -from [get_clocks clk50*] -to   [get_clocks clk125*]
  ###set_false_path -to   [get_clocks clk50*] -from [get_clocks clk125*]
  
  ##set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk25]
  ##set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets clk125]
  ##set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets clk50]

  ###set_false_path -from [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT0]] -to [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT3]]
  ###set_false_path -from [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT0]] -to [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT2]]
  ###set_false_path -from [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT0]] -to [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]]
  ###set_false_path -from [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT2]] -to [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]]
  ###set_false_path -from [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT3]] -to [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]]
  ###set_false_path -from [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -to [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT3]]
  ###set_false_path -from [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -to [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT2]]
  ###set_false_path -from [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -to [get_clocks -of_objects [get_pins eth1.PLLE2_ADV0/CLKOUT0]]
  ###set_false_path -from [get_clocks -of_objects [get_pins mig_gen.gen_mig.gen_ahb2mig.ddrc/gen_mig.MCB_inst/u_mig_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]] -to [get_clocks -of_objects [get_pins eth0.sgmii0/sgmii0.mmcm_adv_inst/CLKOUT0]]

  # Section 4.10.2.2
  ##set_output_delay -clock [get_clocks clk25*] -max -1.0 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}]
  ##set_output_delay -clock [get_clocks clk25*] -min -2.6 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay
  ##set_output_delay -clock [get_clocks clk25*] -clock_fall -max -1.0 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay
  ##set_output_delay -clock [get_clocks clk25*] -clock_fall -min -2.6 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay
  #set_output_delay -clock [get_clocks clk125*] -max -1.0 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}]
  #set_output_delay -clock [get_clocks clk125*] -min -2.6 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay
  #set_output_delay -clock [get_clocks clk125*] -clock_fall -max -1.0 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay
  #set_output_delay -clock [get_clocks clk125*] -clock_fall -min -2.6 [get_ports {rgmii_port_0_td[*] rgmii_port_0_tx_ctl}] -add_delay

  #}

# Define I/O standards
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_1_rd[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports mdio_io_port_0_mdio_io]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_1_rd[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {ref_clk_fsel}]
set_property IOSTANDARD LVCMOS25 [get_ports mdio_io_port_1_mdio_io]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_3_rxc]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_3_rx_ctl]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_3_rd[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_3_rd[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_1_rxc]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_1_rx_ctl]
set_property IOSTANDARD LVCMOS25 [get_ports mdio_io_port_0_mdc]
set_property IOSTANDARD LVCMOS25 [get_ports reset_port_0]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_1_rd[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_1_rd[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {ref_clk_oe}]
set_property IOSTANDARD LVCMOS25 [get_ports mdio_io_port_1_mdc]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_2_rxc]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_2_rd[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_2_rd[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_3_rd[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_3_rd[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_0_rxc]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_0_rx_ctl]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_0_rd[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_0_rd[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_0_td[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_0_td[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_1_td[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_1_td[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_1_td[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_2_rx_ctl]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_2_rd[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_2_td[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_2_td[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_2_tx_ctl]
set_property IOSTANDARD LVCMOS25 [get_ports mdio_io_port_2_mdio_io]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_3_td[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_3_td[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_3_td[3]}]
set_property IOSTANDARD LVDS_25     [get_ports ref_clk_clk_p]
set_property IOSTANDARD LVDS_25     [get_ports ref_clk_clk_n]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_0_rd[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_0_rd[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_0_td[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_0_txc]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_0_td[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_0_tx_ctl]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_1_td[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_1_txc]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_1_tx_ctl]
set_property IOSTANDARD LVCMOS25 [get_ports reset_port_1]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_2_rd[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_2_td[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_2_txc]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_2_td[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports mdio_io_port_2_mdc]
set_property IOSTANDARD LVCMOS25 [get_ports reset_port_2]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_port_3_td[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_3_txc]
set_property IOSTANDARD LVCMOS25 [get_ports rgmii_port_3_tx_ctl]
set_property IOSTANDARD LVCMOS25 [get_ports mdio_io_port_3_mdc]
set_property IOSTANDARD LVCMOS25 [get_ports mdio_io_port_3_mdio_io]
set_property IOSTANDARD LVCMOS25 [get_ports reset_port_3]

set_property PACKAGE_PIN G19 [get_ports {rgmii_port_1_rd[0]}]
set_property PACKAGE_PIN F20 [get_ports mdio_io_port_0_mdio_io]
set_property PACKAGE_PIN A18 [get_ports {rgmii_port_1_rd[2]}]
set_property PACKAGE_PIN C21 [get_ports {ref_clk_fsel}]
set_property PACKAGE_PIN B21 [get_ports mdio_io_port_1_mdio_io]
set_property PACKAGE_PIN G20 [get_ports rgmii_port_3_rxc]
set_property PACKAGE_PIN G21 [get_ports rgmii_port_3_rx_ctl]
set_property PACKAGE_PIN F23 [get_ports {rgmii_port_3_rd[1]}]
set_property PACKAGE_PIN E23 [get_ports {rgmii_port_3_rd[3]}]
set_property PACKAGE_PIN E17 [get_ports rgmii_port_1_rxc]
set_property PACKAGE_PIN E18 [get_ports rgmii_port_1_rx_ctl]
set_property PACKAGE_PIN G15 [get_ports mdio_io_port_0_mdc]
set_property PACKAGE_PIN F15 [get_ports reset_port_0]
set_property PACKAGE_PIN E16 [get_ports {rgmii_port_1_rd[1]}]
set_property PACKAGE_PIN D16 [get_ports {rgmii_port_1_rd[3]}]
set_property PACKAGE_PIN B20 [get_ports {ref_clk_oe}]
set_property PACKAGE_PIN A20 [get_ports mdio_io_port_1_mdc]
set_property PACKAGE_PIN K21 [get_ports rgmii_port_2_rxc]
set_property PACKAGE_PIN K20 [get_ports {rgmii_port_2_rd[2]}]
set_property PACKAGE_PIN J20 [get_ports {rgmii_port_2_rd[3]}]
set_property PACKAGE_PIN J24 [get_ports {rgmii_port_3_rd[0]}]
set_property PACKAGE_PIN H24 [get_ports {rgmii_port_3_rd[2]}]
set_property PACKAGE_PIN D18 [get_ports rgmii_port_0_rxc]
set_property PACKAGE_PIN C18 [get_ports rgmii_port_0_rx_ctl]
set_property PACKAGE_PIN G17 [get_ports {rgmii_port_0_rd[2]}]
set_property PACKAGE_PIN F17 [get_ports {rgmii_port_0_rd[3]}]
set_property PACKAGE_PIN C17 [get_ports {rgmii_port_0_td[1]}]
set_property PACKAGE_PIN B17 [get_ports {rgmii_port_0_td[2]}]
set_property PACKAGE_PIN D20 [get_ports {rgmii_port_1_td[0]}]
set_property PACKAGE_PIN E21 [get_ports {rgmii_port_1_td[2]}]
set_property PACKAGE_PIN D21 [get_ports {rgmii_port_1_td[3]}]
set_property PACKAGE_PIN M16 [get_ports rgmii_port_2_rx_ctl]
set_property PACKAGE_PIN M17 [get_ports {rgmii_port_2_rd[0]}]
set_property PACKAGE_PIN L17 [get_ports {rgmii_port_2_td[1]}]
set_property PACKAGE_PIN L18 [get_ports {rgmii_port_2_td[2]}]
set_property PACKAGE_PIN G22 [get_ports rgmii_port_2_tx_ctl]
set_property PACKAGE_PIN F22 [get_ports mdio_io_port_2_mdio_io]
set_property PACKAGE_PIN F24 [get_ports {rgmii_port_3_td[0]}]
set_property PACKAGE_PIN E26 [get_ports {rgmii_port_3_td[2]}]
set_property PACKAGE_PIN D26 [get_ports {rgmii_port_3_td[3]}]
set_property PACKAGE_PIN D19 [get_ports ref_clk_clk_p]
set_property PACKAGE_PIN C19 [get_ports ref_clk_clk_n]
set_property PACKAGE_PIN H14 [get_ports {rgmii_port_0_rd[0]}]
set_property PACKAGE_PIN H15 [get_ports {rgmii_port_0_rd[1]}]
set_property PACKAGE_PIN F18 [get_ports {rgmii_port_0_td[0]}]
set_property PACKAGE_PIN F19 [get_ports rgmii_port_0_txc]
set_property PACKAGE_PIN H16 [get_ports {rgmii_port_0_td[3]}]
set_property PACKAGE_PIN G16 [get_ports rgmii_port_0_tx_ctl]
set_property PACKAGE_PIN B19 [get_ports {rgmii_port_1_td[1]}]
set_property PACKAGE_PIN A19 [get_ports rgmii_port_1_txc]
set_property PACKAGE_PIN B22 [get_ports rgmii_port_1_tx_ctl]
set_property PACKAGE_PIN A22 [get_ports reset_port_1]
set_property PACKAGE_PIN M14 [get_ports {rgmii_port_2_rd[1]}]
set_property PACKAGE_PIN L14 [get_ports {rgmii_port_2_td[0]}]
set_property PACKAGE_PIN J19 [get_ports rgmii_port_2_txc]
set_property PACKAGE_PIN H19 [get_ports {rgmii_port_2_td[3]}]
set_property PACKAGE_PIN J18 [get_ports mdio_io_port_2_mdc]
set_property PACKAGE_PIN H18 [get_ports reset_port_2]
set_property PACKAGE_PIN K22 [get_ports {rgmii_port_3_td[1]}]
set_property PACKAGE_PIN K23 [get_ports rgmii_port_3_txc]
set_property PACKAGE_PIN E25 [get_ports rgmii_port_3_tx_ctl]
set_property PACKAGE_PIN D25 [get_ports mdio_io_port_3_mdc]
set_property PACKAGE_PIN H26 [get_ports mdio_io_port_3_mdio_io]
set_property PACKAGE_PIN G26 [get_ports reset_port_3]

#-----------------------------------------------------------
# Pins etc.
#-----------------------------------------------------------

# System Clock
set_property PACKAGE_PIN R3         [get_ports clk200p]
set_property PACKAGE_PIN P3         [get_ports clk200n]
set_property IOSTANDARD DIFF_SSTL15 [get_ports clk200p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports clk200n]
set_property VCCAUX_IO DONTCARE     [get_ports clk200p]
set_property VCCAUX_IO DONTCARE     [get_ports clk200n]

#set_property slave_banks {32 34} [get_iobanks 33]
#set_property DCI_CASCADE {32 34} [get_iobanks 33]

# Reset is set to CPU_RESET
set_property PACKAGE_PIN U4      [get_ports reset]
set_property IOSTANDARD LVCMOS15 [get_ports reset]

# --- SPI FLASH
set_property PACKAGE_PIN P18 [get_ports spi_sel_n]
#set_property PACKAGE_PIN H13 [get_ports spi_clk]
set_property PACKAGE_PIN R15 [get_ports spi_miso]
set_property PACKAGE_PIN R14 [get_ports spi_mosi]

set_property IOSTANDARD LVCMOS33 [get_ports spi_*]

# --- SPI SDCARD
set_property PACKAGE_PIN P21 [get_ports sdcard_spi_cs_b]
set_property PACKAGE_PIN N24 [get_ports sdcard_spi_clk]
set_property PACKAGE_PIN P19 [get_ports sdcard_spi_miso]
set_property PACKAGE_PIN N23 [get_ports sdcard_spi_mosi]

set_property IOSTANDARD LVCMOS33 [get_ports sdcard_spi_*]

# UART - Checked
set_property PACKAGE_PIN T19 [get_ports dsutx]
set_property PACKAGE_PIN W19 [get_ports dsuctsn]
set_property PACKAGE_PIN U19 [get_ports dsurx]
set_property PACKAGE_PIN V19 [get_ports dsurtsn]

set_property IOSTANDARD LVCMOS18 [get_ports dsu*]

# Buttons
set_property PACKAGE_PIN P6 [get_ports {button[0]}]
set_property PACKAGE_PIN T5 [get_ports {button[1]}]
set_property PACKAGE_PIN R5 [get_ports {button[2]}]
set_property PACKAGE_PIN U6 [get_ports {button[3]}]

set_property IOSTANDARD LVCMOS15 [get_ports {button[0]}]
set_property IOSTANDARD SSTL15   [get_ports {button[1]}]
set_property IOSTANDARD SSTL15   [get_ports {button[2]}]
set_property IOSTANDARD SSTL15   [get_ports {button[3]}]

# LED Interface
set_property PACKAGE_PIN M26 [get_ports {led[0]}]
set_property PACKAGE_PIN T24 [get_ports {led[1]}]
set_property PACKAGE_PIN T25 [get_ports {led[2]}]
set_property PACKAGE_PIN R26 [get_ports {led[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports led*]

# Switches
set_property PACKAGE_PIN R8  [get_ports {switch[0]}]
set_property PACKAGE_PIN P8  [get_ports {switch[1]}]
set_property PACKAGE_PIN R7  [get_ports {switch[2]}]
set_property PACKAGE_PIN R6  [get_ports {switch[3]}]

set_property IOSTANDARD SSTL15 [get_ports switch*]

# I2C
set_property PACKAGE_PIN N18 [get_ports iic_scl]
set_property PACKAGE_PIN K25 [get_ports iic_sda]

set_property IOSTANDARD LVCMOS33 [get_ports iic*]

