set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

#uncomment for mig
create_clock -period 10.000 -name clkm [get_nets mig_gen.gen_mig.ahb2mig_7series_cpci_xc7k_1/MCB_inst/ui_clk]

#uncomment with no mig
#create_clock -period 10.000 -name clkm [get_nets clkml]



#create_clock -period 30.000 -name pci_clk [get_ports pci_clk]

create_clock -period 10.000 -name spwclk [get_ports spwclk]

create_clock -period 8.000 -name eth_rxclk [get_ports eth_rxclk]
set_propagated_clock [get_clocks eth_rxclk]

#create_clock -period 8.000 -name eth_gtxclk [get_nets ethi\[gtx_clk\]]
#set_propagated_clock [get_clocks eth_gtxclk]

create_clock -period 8.000 -name eth_txclk [get_ports eth_txclk]
set_propagated_clock [get_clocks eth_txclk]

create_clock -period 40.000 -name m1553clk [get_ports m1553clk]
set_propagated_clock [get_clocks m1553clk]

#
# --- Clock Domain Crossings

# --- False paths
#set_false_path -to [get_ports {led[*]}]
#set_false_path -from [get_ports {button[*]}]
set_false_path -from [get_ports resetn]
set_false_path -from [get_ports switch*]
set_false_path -to [get_ports switch*]
set_false_path -from [get_clocks -of_objects [get_pins mig_gen.gen_mig.clkgenmigref0/xc7l.v/PLLE2_ADV_inst/CLKOUT0]] -to [get_clocks clkm]
set_false_path -from [get_clocks m1553clk] -to [get_clocks clkm]
set_false_path -from [get_clocks m1553clk] -to [get_clocks clkm]
set_false_path -from [get_clocks spwclk] -to [get_clocks clkm]
set_false_path -from [get_clocks clkm] -to [get_clocks -of_objects [get_pins mig_gen.gen_mig.clkgenmigref0/xc7l.v/PLLE2_ADV_inst/CLKOUT0]]
set_false_path -from [get_clocks clkm] -to [get_clocks m1553clk]
set_false_path -from [get_clocks clkm] -to [get_clocks spwclk]
set_false_path -from [get_clocks m1553clk] -to [get_clocks clkm]


# --- Flash
# Outputs
set_output_delay -clock [get_clocks clkm] -max 1.000 [get_ports oen]
set_output_delay -clock [get_clocks clkm] -min -add_delay -1.000 [get_ports oen]
set_output_delay -clock [get_clocks clkm] -max 1.000 [get_ports writen]
set_output_delay -clock [get_clocks clkm] -min -add_delay -1.000 [get_ports writen]
set_output_delay -clock [get_clocks clkm] -max 1.000 [get_ports csn]
set_output_delay -clock [get_clocks clkm] -min -add_delay -1.000 [get_ports csn]
#set_output_delay -clock [get_clocks clkm] -max 1.000 [get_ports adv]
#set_output_delay -clock [get_clocks clkm] -min -add_delay -1.000 [get_ports adv]

# --- PCI

# --- SPI FLASH
#set_input_delay   -clock [get_clocks clkm] -max 3.000 [get_ports spi_sel_n]
##set_output_delay -clock [get_clocks clkm] -max 1.000 [get_ports spi_clk  ]
#set_input_delay   -clock [get_clocks clkm] -max 3.000 [get_ports spi_miso ]
#set_output_delay  -clock [get_clocks clkm] -max 1.000 [get_ports spi_mosi ]

# BiDir
#set_input_delay -clock [get_clocks clkm] -max 3.000 [get_ports d*]
#set_input_delay -clock [get_clocks clkm] -min -add_delay 1.000 [get_ports d*]
#set_output_delay -clock [get_clocks clkm] -max -add_delay 1.000 [get_ports d*]
#set_output_delay -clock [get_clocks clkm] -min -add_delay -1.000 [get_ports d*]

# --- UART
# Inputs
set_input_delay -clock [get_clocks clkm] -max 3.000 [get_ports dsurx]
set_input_delay -clock [get_clocks clkm] -min -add_delay 1.000 [get_ports dsurx]
#set_input_delay -clock [get_clocks clkm] -max 3.000 [get_ports dsuctsn]
#set_input_delay -clock [get_clocks clkm] -min -add_delay 1.000 [get_ports dsuctsn]

# Outputs
set_output_delay -clock [get_clocks clkm] -max 1.000 [get_ports dsutx]
set_output_delay -clock [get_clocks clkm] -min -add_delay -1.000 [get_ports dsutx]
#set_output_delay -clock [get_clocks clkm] -max 1.000 [get_ports dsurtsn]
#set_output_delay -clock [get_clocks clkm] -min -add_delay -1.000 [get_ports dsurtsn]

# --- JTAG
# TBD....

# --- I2C
# BiDir
set_input_delay -clock [get_clocks clkm] -max 3.000 [get_ports iic_scl*]
set_input_delay -clock [get_clocks clkm] -min -add_delay 1.000 [get_ports iic_scl*]
set_output_delay -clock [get_clocks clkm] -max -add_delay 1.000 [get_ports iic_scl*]
set_output_delay -clock [get_clocks clkm] -min -add_delay -1.000 [get_ports iic_scl*]
set_input_delay -clock [get_clocks clkm] -max 3.000 [get_ports iic_sda*]
set_input_delay -clock [get_clocks clkm] -min -add_delay 1.000 [get_ports iic_sda*]
set_output_delay -clock [get_clocks clkm] -max -add_delay 1.000 [get_ports iic_sda*]
set_output_delay -clock [get_clocks clkm] -min -add_delay -1.000 [get_ports iic_sda*]

#-----------------------------------------------------------
#              Ethernet / GMII                            -
#-----------------------------------------------------------

set_property IOSTANDARD LVCMOS33 [get_ports eth_*]

set_property PACKAGE_PIN AE23 [get_ports eth_gtxclk]

set_property PACKAGE_PIN Y24 [get_ports eth_mdc]
set_property PACKAGE_PIN Y21 [get_ports eth_mdint]
set_property PACKAGE_PIN AA21 [get_ports eth_mdio]

set_property PACKAGE_PIN AF22 [get_ports eth_rxclk]

set_property PACKAGE_PIN AB24 [get_ports {eth_rxd[0]}]
set_property PACKAGE_PIN AB20 [get_ports {eth_rxd[1]}]
set_property PACKAGE_PIN AC21 [get_ports {eth_rxd[2]}]
set_property PACKAGE_PIN AC20 [get_ports {eth_rxd[3]}]
set_property PACKAGE_PIN AC25 [get_ports {eth_rxd[4]}]
set_property PACKAGE_PIN AB23 [get_ports {eth_rxd[5]}]
set_property PACKAGE_PIN AA22 [get_ports {eth_rxd[6]}]
set_property PACKAGE_PIN AB22 [get_ports {eth_rxd[7]}]

set_property PACKAGE_PIN Y20 [get_ports eth_rxdv]
set_property PACKAGE_PIN AA23 [get_ports eth_rxer]

set_property PACKAGE_PIN AD23 [get_ports eth_txclk]

set_property PACKAGE_PIN AK24 [get_ports {eth_txd[0]}]
set_property PACKAGE_PIN AE25 [get_ports {eth_txd[1]}]
set_property PACKAGE_PIN AH24 [get_ports {eth_txd[2]}]
set_property PACKAGE_PIN AJ24 [get_ports {eth_txd[3]}]
set_property PACKAGE_PIN AF25 [get_ports {eth_txd[4]}]
set_property PACKAGE_PIN AG25 [get_ports {eth_txd[5]}]
set_property PACKAGE_PIN AK25 [get_ports {eth_txd[6]}]

set_property PACKAGE_PIN AK23 [get_ports {eth_txd[7]}]
set_property PACKAGE_PIN AG23 [get_ports eth_txen]
set_property PACKAGE_PIN AG24 [get_ports eth_txer]

set_property PACKAGE_PIN AA20 [get_ports eth_col]
set_property PACKAGE_PIN Y23 [get_ports eth_crs]


#set_property PACKAGE_PIN xxx [get_ports phy_reset]


# The following are required to maximise setup/hold
set_property SLEW FAST [get_ports {eth_txd[7]}]
set_property SLEW FAST [get_ports {eth_txd[6]}]
set_property SLEW FAST [get_ports {eth_txd[5]}]
set_property SLEW FAST [get_ports {eth_txd[4]}]
set_property SLEW FAST [get_ports {eth_txd[3]}]
set_property SLEW FAST [get_ports {eth_txd[2]}]
set_property SLEW FAST [get_ports {eth_txd[1]}]
set_property SLEW FAST [get_ports {eth_txd[0]}]
set_property SLEW FAST [get_ports eth_txen]
set_property SLEW FAST [get_ports eth_txer]


#create_clock -period 8.000 -name eth_gtxclk [get_pins eth0.gtrefclk_pad/xcv.u0/*/O]
#create_clock -period 8.000 -name eth_gtxclk [get_pins eth0.ibufds_gtrefclk/O]
#set_propagated_clock [get_clocks eth_gtxclk]

# CDC
#set_max_delay -datapath_only -from [all_registers -clock [get_clocks clkm]] -to [all_registers -clock [get_clocks eth_rxclk]] 8.000
#set_max_delay -datapath_only -from [all_registers -clock [get_clocks clkm]] -to [all_registers -clock [get_clocks eth_rxclk]] 8.000
#set_max_delay -datapath_only -from [all_registers -clock [get_clocks clkm]    ] -to [all_registers -clock [get_clocks -include_generated_clocks eth_gtxclk]] 8.000
#set_max_delay -datapath_only -from [all_registers -clock [get_clocks eth_rxclk]] -to [all_registers -clock [get_clocks clkm]] 8.000
#set_max_delay -datapath_only -from [all_registers -clock [get_clocks eth_rxclk]] -to [all_registers -clock [get_clocks clkm]] 8.000
#set_max_delay -datapath_only -from [all_registers -clock [get_clocks -include_generated_clocks eth_gtxclk]] -to [all_registers -clock [get_clocks clkm]    ] 8.000

# Output MUX
# Data and Control
#set_false_path -from [get_clocks clkm] -through [get_ports eth_tx*] -to [get_clocks -include_generated_clocks eth_gtxclk]
#set_false_path -from [get_clocks -include_generated_clocks eth_gtxclk] -through [get_ports eth_tx*] -to [get_clocks clkm]

# Outputs
#set_output_delay -clock [get_clocks -include_generated_clocks eth_gtxclk] -max 2.000 [get_ports eth_txd[*]]
#set_output_delay -clock [get_clocks -include_generated_clocks eth_gtxclk] -min 1.000 [get_ports eth_txd[*]]
#set_output_delay -clock [get_clocks -include_generated_clocks eth_gtxclk] -max 2.000 [get_ports eth_txd[*]] -add_delay -clock_fall
#set_output_delay -clock [get_clocks -include_generated_clocks eth_gtxclk] -min 1.000 [get_ports eth_txd[*]] -add_delay -clock_fall

#set_output_delay -clock [get_clocks -include_generated_clocks eth_gtxclk] -max 2.000 [get_ports eth_txen]
#set_output_delay -clock [get_clocks -include_generated_clocks eth_gtxclk] -min 1.000 [get_ports eth_txen]
#set_output_delay -clock [get_clocks -include_generated_clocks eth_gtxclk] -max 2.000 [get_ports eth_txen] -add_delay -clock_fall
#set_output_delay -clock [get_clocks -include_generated_clocks eth_gtxclk] -min 1.000 [get_ports eth_txen] -add_delay -clock_fall

#output timing for rgmii - derated slightly due to pessimism in the tools
#create_generated_clock -name rgmii_tx_clk -divide_by 1 -source [get_pins eth0.rgmii0/*rgmii_tx_clk/*/*/C] [get_ports eth_gtxclk]

#set_output_delay 0.75 -max -clock [get_clocks rgmii_tx_clk] [get_ports {eth_txd[*] eth_txen}]
#set_output_delay -0.7 -min -clock [get_clocks rgmii_tx_clk] [get_ports {eth_txd[*] eth_txen}]
#set_output_delay 0.75 -max -clock [get_clocks rgmii_tx_clk] [get_ports {eth_txd[*] eth_txen}] -clock_fall -add_delay
#set_output_delay -0.7 -min -clock [get_clocks rgmii_tx_clk] [get_ports {eth_txd[*] eth_txen}] -clock_fall -add_delay

# Inputs
#set_input_delay -clock [get_clocks eth_rxclk] -max 1.000 [get_ports {eth_rxd[*] eth_rxdv}]
#set_input_delay -clock [get_clocks eth_rxclk] -min 0.000 [get_ports {eth_rxd[*] eth_rxdv}]
#set_input_delay -clock [get_clocks eth_rxclk] -max 1.000 [get_ports {eth_rxd[*] eth_rxdv}] -add_delay -clock_fall
#set_input_delay -clock [get_clocks eth_rxclk] -min 0.000 [get_ports {eth_rxd[*] eth_rxdv}] -add_delay -clock_fall

# False paths
#set_false_path -to [get_ports phy_reset]
#set_false_path -from [get_ports eth_col]
#set_false_path -from [get_ports eth_crs]
set_false_path -from [get_ports eth_mdint]

# MDIO BiDir
set_input_delay -clock [get_clocks clkm] -max 5.000 [get_ports eth_mdio]
set_input_delay -clock [get_clocks clkm] -min -add_delay 1.000 [get_ports eth_mdio]
set_output_delay -clock [get_clocks clkm] -max -add_delay 1.000 [get_ports eth_mdio]
set_output_delay -clock [get_clocks clkm] -min -add_delay -1.000 [get_ports eth_mdio]

# MDIO - Outputs
set_output_delay -clock [get_clocks clkm] -max 1.000 [get_ports eth_mdc]
set_output_delay -clock [get_clocks clkm] -min -add_delay -1.000 [get_ports eth_mdc]

# apply the same IDELAY_VALUE to all GMII RX inputs
#set_property IDELAY_VALUE 20 [get_cells {eth0.delay* eth0.rgmii*.delay*}]

# Group IODELAY and IDELAYCTRL components to aid placement
#set_property IODELAY_GROUP kc705_ethernet_rgmii_grp1 [get_cells {eth0.delay* eth0.rgmii*.delay*}]
#set_property IODELAY_GROUP kc705_ethernet_rgmii_grp1 [get_cells {eth0.dlyctrl0}]


#-----------------------------------------------------------
# Pins etc.
#-----------------------------------------------------------

# clk is a 50 MHz clock input

set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN C25 [get_ports clk]

# clk_n/clk_p are a LVDL differential 200 MHz clock

#set_property IOSTANDARD LVDS [get_ports clk_p]
#set_property IOSTANDARD LVDS [get_ports clk_n]
#set_property VCCAUX_IO DONTCARE [get_ports clk_p]
#set_property VCCAUX_IO DONTCARE [get_ports clk_n]

#set_property PACKAGE_PIN AH4 [get_ports {clk_n}]
#set_property PACKAGE_PIN AJ4 [get_ports {clk_p}]

# main reset

set_property IOSTANDARD LVCMOS33 [get_ports resetn]

set_property PACKAGE_PIN AC27 [get_ports resetn]


# interface pins for dual MIL1553 interface

set_property IOSTANDARD LVCMOS33 [get_ports m1553*]

set_property PACKAGE_PIN R28 [get_ports m1553clk]
set_property PACKAGE_PIN P29 [get_ports m1553rxa]
set_property PACKAGE_PIN P26 [get_ports m1553rxb]
set_property PACKAGE_PIN U20 [get_ports m1553rxena]
set_property PACKAGE_PIN T30 [get_ports m1553rxenb]
set_property PACKAGE_PIN R29 [get_ports m1553rxna]
set_property PACKAGE_PIN R26 [get_ports m1553rxnb]
set_property PACKAGE_PIN T22 [get_ports m1553txa]
set_property PACKAGE_PIN P28 [get_ports m1553txb]
set_property PACKAGE_PIN T21 [get_ports m1553txinha]
set_property PACKAGE_PIN P27 [get_ports m1553txinhb]
set_property PACKAGE_PIN T23 [get_ports m1553txna]
set_property PACKAGE_PIN R30 [get_ports m1553txnb]


# interface pins for SRAM / NOR flash interface (8 bits data)

set_property IOSTANDARD LVCMOS33 [get_ports a*]

set_property PACKAGE_PIN L25 [get_ports {a[0]}]
set_property PACKAGE_PIN J23 [get_ports {a[1]}]
set_property PACKAGE_PIN J24 [get_ports {a[2]}]
set_property PACKAGE_PIN J22 [get_ports {a[3]}]
set_property PACKAGE_PIN L23 [get_ports {a[4]}]
set_property PACKAGE_PIN K23 [get_ports {a[5]}]
set_property PACKAGE_PIN K24 [get_ports {a[6]}]
set_property PACKAGE_PIN H29 [get_ports {a[7]}]
set_property PACKAGE_PIN K21 [get_ports {a[8]}]
set_property PACKAGE_PIN J21 [get_ports {a[9]}]
set_property PACKAGE_PIN L22 [get_ports {a[10]}]
set_property PACKAGE_PIN M20 [get_ports {a[11]}]
set_property PACKAGE_PIN K25 [get_ports {a[12]}]
set_property PACKAGE_PIN J26 [get_ports {a[13]}]
set_property PACKAGE_PIN L21 [get_ports {a[14]}]
set_property PACKAGE_PIN J27 [get_ports {a[15]}]
set_property PACKAGE_PIN J28 [get_ports {a[16]}]
set_property PACKAGE_PIN M28 [get_ports {a[17]}]
set_property PACKAGE_PIN N25 [get_ports {a[18]}]
set_property PACKAGE_PIN K26 [get_ports {a[19]}]
set_property PACKAGE_PIN J29 [get_ports {a[20]}]
set_property PACKAGE_PIN L26 [get_ports {a[21]}]
set_property PACKAGE_PIN L27 [get_ports {a[22]}]
set_property PACKAGE_PIN M19 [get_ports {a[23]}]
set_property PACKAGE_PIN L20 [get_ports {a[24]}]


set_property IOSTANDARD LVCMOS33 [get_ports {d[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {d[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {d[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {d[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {d[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {d[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {d[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {d[0]}]

set_property PACKAGE_PIN L28 [get_ports {d[0]}]
set_property PACKAGE_PIN K29 [get_ports {d[1]}]
set_property PACKAGE_PIN M30 [get_ports {d[2]}]
set_property PACKAGE_PIN N27 [get_ports {d[3]}]
set_property PACKAGE_PIN M27 [get_ports {d[4]}]
set_property PACKAGE_PIN K28 [get_ports {d[5]}]
set_property PACKAGE_PIN M29 [get_ports {d[6]}]
set_property PACKAGE_PIN L30 [get_ports {d[7]}]


set_property IOSTANDARD LVCMOS33 [get_ports csn*]

set_property PACKAGE_PIN N29 [get_ports {csn[0]}]
set_property PACKAGE_PIN N30 [get_ports {csn[1]}]
set_property PACKAGE_PIN K30 [get_ports {csn[2]}]
set_property PACKAGE_PIN N26 [get_ports {csn[3]}]
set_property PACKAGE_PIN N19 [get_ports {csn[4]}]
set_property PACKAGE_PIN N20 [get_ports {csn[5]}]


set_property IOSTANDARD LVCMOS33 [get_ports oen*]

set_property PACKAGE_PIN N22 [get_ports oen]

set_property IOSTANDARD LVCMOS33 [get_ports writen*]

set_property PACKAGE_PIN N21 [get_ports writen]

# interface pins for dual CAN interface

set_property IOSTANDARD LVCMOS33 [get_ports can*]

set_property PACKAGE_PIN AH21 [get_ports canrxa]
set_property PACKAGE_PIN AK21 [get_ports canrxb]
set_property PACKAGE_PIN AJ21 [get_ports cansela]
set_property PACKAGE_PIN AE20 [get_ports canselb]
set_property PACKAGE_PIN AH20 [get_ports cantxa]
set_property PACKAGE_PIN AK20 [get_ports cantxb]


# interface pins for DDR3 memory interface - 16 bit data

#set_property slave_banks {32 34} [get_iobanks 33]
#set_property DCI_CASCADE {32 34} [get_iobanks 33]


set_property IOSTANDARD SSTL15 [get_ports ddr3_addr*]
set_property PACKAGE_PIN AE4 [get_ports {ddr3_addr[0]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[0]}]
set_property PACKAGE_PIN AE3 [get_ports {ddr3_addr[1]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[1]}]
set_property PACKAGE_PIN AG4 [get_ports {ddr3_addr[2]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[2]}]
set_property PACKAGE_PIN AF2 [get_ports {ddr3_addr[3]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[3]}]
set_property PACKAGE_PIN AD3 [get_ports {ddr3_addr[4]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[4]}]
set_property PACKAGE_PIN AF3 [get_ports {ddr3_addr[5]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[5]}]
set_property PACKAGE_PIN AE6 [get_ports {ddr3_addr[6]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[6]}]
set_property PACKAGE_PIN AF5 [get_ports {ddr3_addr[7]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[7]}]
set_property PACKAGE_PIN AE5 [get_ports {ddr3_addr[8]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[8]}]
set_property PACKAGE_PIN AG2 [get_ports {ddr3_addr[9]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[9]}]
set_property PACKAGE_PIN AC5 [get_ports {ddr3_addr[10]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[10]}]
set_property PACKAGE_PIN AE1 [get_ports {ddr3_addr[11]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[11]}]
set_property PACKAGE_PIN AC2 [get_ports {ddr3_addr[12]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[12]}]
set_property PACKAGE_PIN AG3 [get_ports {ddr3_addr[13]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[13]}]
set_property PACKAGE_PIN AF1 [get_ports {ddr3_addr[14]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_addr[14]}]

set_property IOSTANDARD SSTL15 [get_ports ddr3_ba*]
set_property PACKAGE_PIN AG5 [get_ports {ddr3_ba[0]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_ba[0]}]
set_property PACKAGE_PIN AD4 [get_ports {ddr3_ba[1]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_ba[1]}]
set_property PACKAGE_PIN AC4 [get_ports {ddr3_ba[2]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_ba[2]}]

set_property IOSTANDARD DIFF_SSTL15 [get_ports ddr3_ck_*]
#set_property IOSTANDARD DIFF_SSTL15  [get_ports {ddr3_ck_n[0]}]
set_property PACKAGE_PIN AD1 [get_ports {ddr3_ck_n[0]}]
set_property PACKAGE_PIN AD2 [get_ports {ddr3_ck_p[0]}]
#set_property IOSTANDARD DIFF_SSTL15  [get_ports {ddr3_ck_p[0]}]

set_property IOSTANDARD SSTL15 [get_ports ddr3_dm*]
set_property PACKAGE_PIN AB8 [get_ports {ddr3_dm[0]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_dm[0]}]
set_property PACKAGE_PIN AE9 [get_ports {ddr3_dm[1]}]
#set_property IOSTANDARD SSTL15  [get_ports {ddr3_dm[1]}]

set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[15]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[14]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[13]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[12]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[11]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[10]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[9]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[8]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[7]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[6]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[5]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[4]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[3]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[2]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[1]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[0]}]
set_property PACKAGE_PIN AA11 [get_ports {ddr3_dq[0]}]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[0]}]
set_property PACKAGE_PIN AA8 [get_ports {ddr3_dq[1]}]
#set_property IOSTANDARD SSTL15_T_DCI  [get_ports {ddr3_dq[1]}]
set_property PACKAGE_PIN AB12 [get_ports {ddr3_dq[2]}]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[2]}]
set_property PACKAGE_PIN AA13 [get_ports {ddr3_dq[3]}]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[3]}]
set_property PACKAGE_PIN AA10 [get_ports {ddr3_dq[4]}]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[4]}]
set_property PACKAGE_PIN Y10 [get_ports {ddr3_dq[5]}]
#set_property IOSTANDARD SSTL15_T_DCI  [get_ports {ddr3_dq[5]}]
set_property PACKAGE_PIN AA12 [get_ports {ddr3_dq[6]}]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[6]}]
set_property PACKAGE_PIN Y11 [get_ports {ddr3_dq[7]}]
#set_property IOSTANDARD SSTL15_T_DCI  [get_ports {ddr3_dq[7]}]
set_property PACKAGE_PIN AB10 [get_ports {ddr3_dq[8]}]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[8]}]
set_property PACKAGE_PIN AD12 [get_ports {ddr3_dq[9]}]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[9]}]
set_property PACKAGE_PIN AC10 [get_ports {ddr3_dq[10]}]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[10]}]
set_property PACKAGE_PIN AE11 [get_ports {ddr3_dq[11]}]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[11]}]
set_property PACKAGE_PIN AE8 [get_ports {ddr3_dq[12]}]
#set_property IOSTANDARD SSTL15_T_DCI  [get_ports {ddr3_dq[12]}]
set_property PACKAGE_PIN AF11 [get_ports {ddr3_dq[13]}]
#set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[13]}]
set_property PACKAGE_PIN AD8 [get_ports {ddr3_dq[14]}]
#set_property IOSTANDARD SSTL15_T_DCI  [get_ports {ddr3_dq[14]}]
set_property PACKAGE_PIN AD9 [get_ports {ddr3_dq[15]}]
#set_property IOSTANDARD SSTL15_T_DCI  [get_ports {ddr3_dq[15]}]

set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports ddr3_dqs_*]
#set_property IOSTANDARD DIFF_SSTL15_T_DCI  [get_ports {ddr3_dqs_n[0]}]
set_property PACKAGE_PIN AB9 [get_ports {ddr3_dqs_p[0]}]
set_property PACKAGE_PIN AC9 [get_ports {ddr3_dqs_n[0]}]
#set_property IOSTANDARD DIFF_SSTL15_T_DCI  [get_ports {ddr3_dqs_p[0]}]
#set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_n[1]}]
set_property PACKAGE_PIN AC11 [get_ports {ddr3_dqs_n[1]}]
set_property PACKAGE_PIN AC12 [get_ports {ddr3_dqs_p[1]}]
#set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_p[1]}]

set_property PACKAGE_PIN AC7 [get_ports {ddr3_cke[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_cke[0]}]
set_property PACKAGE_PIN AF6 [get_ports {ddr3_cs_n[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_cs_n[0]}]
set_property PACKAGE_PIN AD6 [get_ports ddr3_cas_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_cas_n]
set_property PACKAGE_PIN AC1 [get_ports ddr3_ras_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_ras_n]
set_property PACKAGE_PIN AH1 [get_ports {ddr3_odt[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_odt[0]}]
set_property PACKAGE_PIN AD7 [get_ports ddr3_we_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_we_n]


set_property PACKAGE_PIN AD11 [get_ports ddr3_reset_n]
set_property IOSTANDARD LVCMOS15 [get_ports ddr3_reset_n]
##set_property PACKAGE_PIN AB13 [get_ports {ddr_vref}]
##set_property PACKAGE_PIN AF13 [get_ports {ddr_vref}]



# interface pins on GPIO headers

set_property IOSTANDARD LVCMOS33 [get_ports gpio*]

set_property PACKAGE_PIN F23 [get_ports {gpio[0]}]
set_property PACKAGE_PIN B23 [get_ports {gpio[1]}]
set_property PACKAGE_PIN E26 [get_ports {gpio[10]}]
set_property PACKAGE_PIN G23 [get_ports {gpio[11]}]
set_property PACKAGE_PIN G24 [get_ports {gpio[12]}]
set_property PACKAGE_PIN B27 [get_ports {gpio[13]}]
set_property PACKAGE_PIN A27 [get_ports {gpio[14]}]
set_property PACKAGE_PIN C24 [get_ports {gpio[15]}]
set_property PACKAGE_PIN B24 [get_ports {gpio[16]}]
set_property PACKAGE_PIN B28 [get_ports {gpio[17]}]
set_property PACKAGE_PIN A28 [get_ports {gpio[18]}]
set_property PACKAGE_PIN A25 [get_ports {gpio[19]}]
set_property PACKAGE_PIN A23 [get_ports {gpio[2]}]
set_property PACKAGE_PIN A26 [get_ports {gpio[20]}]
set_property PACKAGE_PIN D26 [get_ports {gpio[21]}]
set_property PACKAGE_PIN C26 [get_ports {gpio[22]}]
set_property PACKAGE_PIN D27 [get_ports {gpio[23]}]
set_property PACKAGE_PIN C27 [get_ports {gpio[24]}]
set_property PACKAGE_PIN E28 [get_ports {gpio[25]}]
set_property PACKAGE_PIN D28 [get_ports {gpio[26]}]
set_property PACKAGE_PIN C29 [get_ports {gpio[27]}]
set_property PACKAGE_PIN B29 [get_ports {gpio[28]}]
set_property PACKAGE_PIN D29 [get_ports {gpio[29]}]
set_property PACKAGE_PIN E23 [get_ports {gpio[3]}]
set_property PACKAGE_PIN C30 [get_ports {gpio[30]}]
set_property PACKAGE_PIN B30 [get_ports {gpio[31]}]
#set_property PACKAGE_PIN K18 [get_ports {gpio[32]}]
#set_property PACKAGE_PIN J18 [get_ports {gpio[33]}]
#set_property PACKAGE_PIN H20 [get_ports {gpio[34]}]
#set_property PACKAGE_PIN G20 [get_ports {gpio[35]}]
#set_property PACKAGE_PIN J17 [get_ports {gpio[36]}]
#set_property PACKAGE_PIN H17 [get_ports {gpio[37]}]
#set_property PACKAGE_PIN J19 [get_ports {gpio[38]}]
#set_property PACKAGE_PIN H19 [get_ports {gpio[39]}]
set_property PACKAGE_PIN D23 [get_ports {gpio[4]}]
#set_property PACKAGE_PIN L17 [get_ports {gpio[40]}]
#set_property PACKAGE_PIN L18 [get_ports {gpio[41]}]
#set_property PACKAGE_PIN K19 [get_ports {gpio[42]}]
#set_property PACKAGE_PIN K20 [get_ports {gpio[43]}]
#set_property PACKAGE_PIN H21 [get_ports {gpio[44]}]
#set_property PACKAGE_PIN H22 [get_ports {gpio[45]}]
#set_property PACKAGE_PIN D21 [get_ports {gpio[46]}]
#set_property PACKAGE_PIN C21 [get_ports {gpio[47]}]
#set_property PACKAGE_PIN A30 [get_ports {gpio[48]}]
#set_property PACKAGE_PIN E29 [get_ports {gpio[49]}]
set_property PACKAGE_PIN F25 [get_ports {gpio[5]}]
#set_property PACKAGE_PIN E30 [get_ports {gpio[50]}]
#set_property PACKAGE_PIN H24 [get_ports {gpio[51]}]
#set_property PACKAGE_PIN H25 [get_ports {gpio[52]}]
#set_property PACKAGE_PIN G28 [get_ports {gpio[53]}]
#set_property PACKAGE_PIN F28 [get_ports {gpio[54]}]
#set_property PACKAGE_PIN G27 [get_ports {gpio[55]}]
#set_property PACKAGE_PIN F27 [get_ports {gpio[56]}]
#set_property PACKAGE_PIN G29 [get_ports {gpio[57]}]
#set_property PACKAGE_PIN F30 [get_ports {gpio[58]}]
#set_property PACKAGE_PIN H26 [get_ports {gpio[59]}]
set_property PACKAGE_PIN E25 [get_ports {gpio[6]}]
#set_property PACKAGE_PIN H27 [get_ports {gpio[60]}]
#set_property PACKAGE_PIN H30 [get_ports {gpio[61]}]
#set_property PACKAGE_PIN G30 [get_ports {gpio[62]}]
#set_property PACKAGE_PIN G25 [get_ports {gpio[63]}]
set_property PACKAGE_PIN E24 [get_ports {gpio[7]}]
set_property PACKAGE_PIN D24 [get_ports {gpio[8]}]
set_property PACKAGE_PIN F26 [get_ports {gpio[9]}]


# interface pins on mezzanine connectors

#set_property IOSTANDARD LVCMOS33 [get_ports mezz*]
#
#set_property PACKAGE_PIN F11 [get_ports {mezz[0]}]
#set_property PACKAGE_PIN E11 [get_ports {mezz[1]}]
#set_property PACKAGE_PIN D11 [get_ports {mezz[2]}]
#set_property PACKAGE_PIN C11 [get_ports {mezz[3]}]
#set_property PACKAGE_PIN C12 [get_ports {mezz[4]}]
#set_property PACKAGE_PIN B12 [get_ports {mezz[5]}]
#set_property PACKAGE_PIN L11 [get_ports {mezz[6]}]
#set_property PACKAGE_PIN K11 [get_ports {mezz[7]}]
#set_property PACKAGE_PIN L12 [get_ports {mezz[8]}]
#set_property PACKAGE_PIN L13 [get_ports {mezz[9]}]
#set_property PACKAGE_PIN E19 [get_ports {mezz[10]}]
#set_property PACKAGE_PIN D19 [get_ports {mezz[11]}]
#set_property PACKAGE_PIN K14 [get_ports {mezz[12]}]
#set_property PACKAGE_PIN J14 [get_ports {mezz[13]}]
#set_property PACKAGE_PIN L16 [get_ports {mezz[14]}]
#set_property PACKAGE_PIN K16 [get_ports {mezz[15]}]
#set_property PACKAGE_PIN D17 [get_ports {mezz[16]}]
#set_property PACKAGE_PIN D18 [get_ports {mezz[17]}]
#set_property PACKAGE_PIN C17 [get_ports {mezz[18]}]
#set_property PACKAGE_PIN B17 [get_ports {mezz[19]}]
#set_property PACKAGE_PIN D16 [get_ports {mezz[20]}]
#set_property PACKAGE_PIN C16 [get_ports {mezz[21]}]
#set_property PACKAGE_PIN C20 [get_ports {mezz[22]}]
#set_property PACKAGE_PIN B20 [get_ports {mezz[23]}]
#set_property PACKAGE_PIN L15 [get_ports {mezz[24]}]
#set_property PACKAGE_PIN K15 [get_ports {mezz[25]}]
#set_property PACKAGE_PIN D12 [get_ports {mezz[26]}]
#set_property PACKAGE_PIN D13 [get_ports {mezz[27]}]
#set_property PACKAGE_PIN K13 [get_ports {mezz[28]}]
#set_property PACKAGE_PIN J13 [get_ports {mezz[29]}]
#set_property PACKAGE_PIN H11 [get_ports {mezz[30]}]
#set_property PACKAGE_PIN H12 [get_ports {mezz[31]}]
#set_property PACKAGE_PIN G13 [get_ports {mezz[32]}]
#set_property PACKAGE_PIN F13 [get_ports {mezz[33]}]
#set_property PACKAGE_PIN H14 [get_ports {mezz[34]}]
#set_property PACKAGE_PIN G14 [get_ports {mezz[35]}]
#set_property PACKAGE_PIN D14 [get_ports {mezz[36]}]
#set_property PACKAGE_PIN C14 [get_ports {mezz[37]}]
#set_property PACKAGE_PIN B13 [get_ports {mezz[38]}]
#set_property PACKAGE_PIN A13 [get_ports {mezz[39]}]
#set_property PACKAGE_PIN B14 [get_ports {mezz[40]}]
#set_property PACKAGE_PIN A15 [get_ports {mezz[41]}]
#set_property PACKAGE_PIN C15 [get_ports {mezz[42]}]
#set_property PACKAGE_PIN B15 [get_ports {mezz[43]}]
#set_property PACKAGE_PIN A11 [get_ports {mezz[44]}]
#set_property PACKAGE_PIN A12 [get_ports {mezz[45]}]
#set_property PACKAGE_PIN E14 [get_ports {mezz[46]}]
#set_property PACKAGE_PIN E15 [get_ports {mezz[47]}]
#set_property PACKAGE_PIN A16 [get_ports {mezz[48]}]
#set_property PACKAGE_PIN A17 [get_ports {mezz[49]}]
#set_property PACKAGE_PIN F15 [get_ports {mezz[50]}]
#set_property PACKAGE_PIN E16 [get_ports {mezz[51]}]
#set_property PACKAGE_PIN B18 [get_ports {mezz[52]}]
#set_property PACKAGE_PIN A18 [get_ports {mezz[53]}]
#set_property PACKAGE_PIN G17 [get_ports {mezz[54]}]
#set_property PACKAGE_PIN F17 [get_ports {mezz[55]}]
#set_property PACKAGE_PIN G18 [get_ports {mezz[56]}]
#set_property PACKAGE_PIN F18 [get_ports {mezz[57]}]
#set_property PACKAGE_PIN F12 [get_ports {mezz[58]}]
#set_property PACKAGE_PIN E13 [get_ports {mezz[59]}]
#set_property PACKAGE_PIN J11 [get_ports {mezz[60]}]
#set_property PACKAGE_PIN J12 [get_ports {mezz[61]}]
#set_property PACKAGE_PIN B22 [get_ports {mezz[62]}]
#set_property PACKAGE_PIN A22 [get_ports {mezz[63]}]
#set_property PACKAGE_PIN H15 [get_ports {mezz[64]}]
#set_property PACKAGE_PIN G15 [get_ports {mezz[65]}]
#set_property PACKAGE_PIN J16 [get_ports {mezz[66]}]
#set_property PACKAGE_PIN H16 [get_ports {mezz[67]}]
#set_property PACKAGE_PIN F20 [get_ports {mezz[68]}]
#set_property PACKAGE_PIN E20 [get_ports {mezz[69]}]
#set_property PACKAGE_PIN D22 [get_ports {mezz[70]}]
#set_property PACKAGE_PIN C22 [get_ports {mezz[71]}]
#set_property PACKAGE_PIN G22 [get_ports {mezz[72]}]
#set_property PACKAGE_PIN F22 [get_ports {mezz[73]}]
#set_property PACKAGE_PIN F21 [get_ports {mezz[74]}]
#set_property PACKAGE_PIN E21 [get_ports {mezz[75]}]
#set_property PACKAGE_PIN C19 [get_ports {mezz[76]}]
#set_property PACKAGE_PIN B19 [get_ports {mezz[77]}]
#set_property PACKAGE_PIN A20 [get_ports {mezz[78]}]
#set_property PACKAGE_PIN A21 [get_ports {mezz[79]}]


# interface pins for two quad bit SPI memory interfaces

set_property IOSTANDARD LVCMOS18 [get_ports {m0_d[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {m0_d[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {m0_d[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {m0_d[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {m0_slvsel[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {m0_slvsel[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {m1_d[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {m1_d[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {m1_d[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {m1_d[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {m1_slvsel[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {m1_slvsel[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports m0_sck]
set_property IOSTANDARD LVCMOS18 [get_ports m1_sck]

set_property PACKAGE_PIN AB15 [get_ports {m0_d[0]}]
set_property PACKAGE_PIN AE14 [get_ports {m0_d[1]}]
set_property PACKAGE_PIN AA15 [get_ports {m0_d[2]}]
set_property PACKAGE_PIN AE15 [get_ports {m0_d[3]}]
set_property PACKAGE_PIN AC15 [get_ports m0_sck]
set_property PACKAGE_PIN AC14 [get_ports {m0_slvsel[0]}]
set_property PACKAGE_PIN AD14 [get_ports {m0_slvsel[1]}]

set_property PACKAGE_PIN AC16 [get_ports {m1_d[0]}]
set_property PACKAGE_PIN AA17 [get_ports {m1_d[1]}]
set_property PACKAGE_PIN AA16 [get_ports {m1_d[2]}]
set_property PACKAGE_PIN AB17 [get_ports {m1_d[3]}]
set_property PACKAGE_PIN AC17 [get_ports m1_sck]
set_property PACKAGE_PIN Y15 [get_ports {m1_slvsel[0]}]
set_property PACKAGE_PIN Y16 [get_ports {m1_slvsel[1]}]


# interface pins for 32 bit PCI interface including 4-bit arbiter

set_property IOSTANDARD PCI33_3 [get_ports pci_*]

set_property PACKAGE_PIN V22 [get_ports {pci_ad[0]}]
set_property PACKAGE_PIN W19 [get_ports {pci_ad[1]}]
set_property PACKAGE_PIN T26 [get_ports {pci_ad[2]}]
set_property PACKAGE_PIN V24 [get_ports {pci_ad[3]}]
set_property PACKAGE_PIN V20 [get_ports {pci_ad[4]}]
set_property PACKAGE_PIN U22 [get_ports {pci_ad[5]}]
set_property PACKAGE_PIN U25 [get_ports {pci_ad[6]}]
set_property PACKAGE_PIN T28 [get_ports {pci_ad[7]}]
set_property PACKAGE_PIN U30 [get_ports {pci_ad[8]}]
set_property PACKAGE_PIN U23 [get_ports {pci_ad[9]}]
set_property PACKAGE_PIN V19 [get_ports {pci_ad[10]}]
set_property PACKAGE_PIN T27 [get_ports {pci_ad[11]}]
set_property PACKAGE_PIN V29 [get_ports {pci_ad[12]}]
set_property PACKAGE_PIN V30 [get_ports {pci_ad[13]}]
set_property PACKAGE_PIN U28 [get_ports {pci_ad[14]}]
set_property PACKAGE_PIN U27 [get_ports {pci_ad[15]}]
set_property PACKAGE_PIN V25 [get_ports {pci_ad[16]}]
set_property PACKAGE_PIN U24 [get_ports {pci_ad[17]}]
set_property PACKAGE_PIN U29 [get_ports {pci_ad[18]}]
set_property PACKAGE_PIN W22 [get_ports {pci_ad[19]}]
set_property PACKAGE_PIN V21 [get_ports {pci_ad[20]}]
set_property PACKAGE_PIN T25 [get_ports {pci_ad[21]}]
set_property PACKAGE_PIN W21 [get_ports {pci_ad[22]}]
set_property PACKAGE_PIN W23 [get_ports {pci_ad[23]}]
set_property PACKAGE_PIN W26 [get_ports {pci_ad[24]}]
set_property PACKAGE_PIN V26 [get_ports {pci_ad[25]}]
set_property PACKAGE_PIN V27 [get_ports {pci_ad[26]}]
set_property PACKAGE_PIN W24 [get_ports {pci_ad[27]}]
set_property PACKAGE_PIN AB30 [get_ports {pci_ad[28]}]
set_property PACKAGE_PIN AC29 [get_ports {pci_ad[29]}]
set_property PACKAGE_PIN AC30 [get_ports {pci_ad[30]}]
set_property PACKAGE_PIN AD29 [get_ports {pci_ad[31]}]
#
set_property PACKAGE_PIN P23 [get_ports {pci_arb_gnt[0]}]
set_property PACKAGE_PIN N24 [get_ports {pci_arb_gnt[1]}]
set_property PACKAGE_PIN P21 [get_ports {pci_arb_gnt[2]}]
set_property PACKAGE_PIN P22 [get_ports {pci_arb_gnt[3]}]
#
set_property PACKAGE_PIN M24 [get_ports {pci_arb_req[0]}]
set_property PACKAGE_PIN M25 [get_ports {pci_arb_req[1]}]
set_property PACKAGE_PIN M22 [get_ports {pci_arb_req[2]}]
set_property PACKAGE_PIN M23 [get_ports {pci_arb_req[3]}]
#
set_property PACKAGE_PIN AD28 [get_ports {pci_cbe[0]}]
set_property PACKAGE_PIN Y28 [get_ports {pci_cbe[1]}]
set_property PACKAGE_PIN AB29 [get_ports {pci_cbe[2]}]
set_property PACKAGE_PIN AA30 [get_ports {pci_cbe[3]}]
#
set_property PACKAGE_PIN AD27 [get_ports pci_clk]
set_property PACKAGE_PIN AA27 [get_ports pci_devsel]
set_property PACKAGE_PIN W27 [get_ports pci_frame]
set_property PACKAGE_PIN AA26 [get_ports pci_gnt]
set_property PACKAGE_PIN Y30 [get_ports pci_host]
set_property PACKAGE_PIN AB25 [get_ports pci_idsel]
set_property PACKAGE_PIN AE29 [get_ports {pci_int[0]}]
set_property PACKAGE_PIN Y29 [get_ports pci_irdy]
set_property PACKAGE_PIN AB28 [get_ports pci_lock]
set_property PACKAGE_PIN Y25 [get_ports pci_par]
set_property PACKAGE_PIN Y26 [get_ports pci_perr]
set_property PACKAGE_PIN W28 [get_ports pci_req]
set_property PACKAGE_PIN AG29 [get_ports pci_rst]
set_property PACKAGE_PIN AA28 [get_ports pci_serr]
set_property PACKAGE_PIN AA25 [get_ports pci_stop]
set_property PACKAGE_PIN W29 [get_ports pci_trdy]


## interface pins for GTX serial interfaces
#
##gtx_clk is an internally generated clock output
#
#set_property PACKAGE_PIN Y18 [get_ports {gtx_clk[0]_n}]
#set_property PACKAGE_PIN Y19 [get_ports {gtx_clk[0]_p}]
#
##gbt_clks are clock inputs
#
#set_property PACKAGE_PIN R7 [get_ports {gbt_clk[0]_n}]
#set_property PACKAGE_PIN R8 [get_ports {gbt_clk[0]_p}]
#set_property PACKAGE_PIN C7 [get_ports {gbt_clk[1]_n}]
#set_property PACKAGE_PIN C8 [get_ports {gbt_clk[1]_p}]
#set_property PACKAGE_PIN L7 [get_ports {gbt_clk[2]_n}]
#set_property PACKAGE_PIN L8 [get_ports {gbt_clk[2]_p}]
#
#set_property PACKAGE_PIN E3 [get_ports {rx_data[0]_n}]
#set_property PACKAGE_PIN E4 [get_ports {rx_data[0]_p}]
#set_property PACKAGE_PIN B5 [get_ports {rx_data[1]_n}]
#set_property PACKAGE_PIN B6 [get_ports {rx_data[1]_p}]
#set_property PACKAGE_PIN T5 [get_ports {rx_data[2]_n}]
#set_property PACKAGE_PIN T6 [get_ports {rx_data[2]_p}]
#set_property PACKAGE_PIN R3 [get_ports {rx_data[3]_n}]
#set_property PACKAGE_PIN R4 [get_ports {rx_data[3]_p}]
#
#set_property PACKAGE_PIN D1 [get_ports {tx_data[0]_n}]
#set_property PACKAGE_PIN D2 [get_ports {tx_data[0]_p}]
#set_property PACKAGE_PIN B1 [get_ports {tx_data[1]_n}]
#set_property PACKAGE_PIN B2 [get_ports {tx_data[1]_p}]
#set_property PACKAGE_PIN P1 [get_ports {tx_data[2]_n}]
#set_property PACKAGE_PIN P2 [get_ports {tx_data[2]_p}]
#set_property PACKAGE_PIN N3 [get_ports {tx_data[3]_n}]
#set_property PACKAGE_PIN N4 [get_ports {tx_data[3]_p}]


# interface pins for QSPI interface to QSPI configuration prom

set_property IOSTANDARD LVCMOS33 [get_ports spi_*]

set_property PACKAGE_PIN U19 [get_ports spi_cs]
set_property PACKAGE_PIN P24 [get_ports {spi_d[0]}]
set_property PACKAGE_PIN R25 [get_ports {spi_d[1]}]
set_property PACKAGE_PIN R20 [get_ports {spi_d[2]}]
set_property PACKAGE_PIN R21 [get_ports {spi_d[3]}]


# interface pins for Spacewire interfaces

set_property IOSTANDARD LVCMOS33 [get_ports spw*]

set_property PACKAGE_PIN AB27 [get_ports spwclk]

set_property PACKAGE_PIN AH26 [get_ports {spw_rxd[0]}]
set_property PACKAGE_PIN AD26 [get_ports {spw_rxd[1]}]
set_property PACKAGE_PIN AJ27 [get_ports {spw_rxd[2]}]
set_property PACKAGE_PIN AK30 [get_ports {spw_rxd[3]}]
set_property PACKAGE_PIN AE28 [get_ports {spw_rxd[4]}]
set_property PACKAGE_PIN AG28 [get_ports {spw_rxd[5]}]
set_property PACKAGE_PIN AG27 [get_ports {spw_rxs[0]}]
set_property PACKAGE_PIN AK29 [get_ports {spw_rxs[1]}]
set_property PACKAGE_PIN AK28 [get_ports {spw_rxs[2]}]
set_property PACKAGE_PIN AH29 [get_ports {spw_rxs[3]}]
set_property PACKAGE_PIN AE30 [get_ports {spw_rxs[4]}]
set_property PACKAGE_PIN AF28 [get_ports {spw_rxs[5]}]
set_property PACKAGE_PIN AK26 [get_ports {spw_txd[0]}]
set_property PACKAGE_PIN AJ29 [get_ports {spw_txd[1]}]
set_property PACKAGE_PIN AH27 [get_ports {spw_txd[2]}]
set_property PACKAGE_PIN AF26 [get_ports {spw_txd[3]}]
set_property PACKAGE_PIN AE26 [get_ports {spw_txd[4]}]
set_property PACKAGE_PIN AF27 [get_ports {spw_txd[5]}]
set_property PACKAGE_PIN AC26 [get_ports {spw_txs[0]}]
set_property PACKAGE_PIN AJ28 [get_ports {spw_txs[1]}]
set_property PACKAGE_PIN AJ26 [get_ports {spw_txs[2]}]
set_property PACKAGE_PIN AH30 [get_ports {spw_txs[3]}]
set_property PACKAGE_PIN AF30 [get_ports {spw_txs[4]}]
set_property PACKAGE_PIN AG30 [get_ports {spw_txs[5]}]




# SPI-SLV gpio[44 -47]
#set_property IOSTANDARD LVCMOS33 [get_ports spislv*]
#set_property PACKAGE_PIN H21 [get_ports {spislv_sck}]
#set_property PACKAGE_PIN H22 [get_ports {spislv_miso}]
#set_property PACKAGE_PIN D21 [get_ports {spislv_mosi}]
#set_property PACKAGE_PIN C21 [get_ports {spislv_sel}]

# Debug UART gpio[48 - 49]
set_property IOSTANDARD LVCMOS33 [get_ports dsurx]
set_property IOSTANDARD LVCMOS33 [get_ports dsutx]
set_property PACKAGE_PIN A30 [get_ports dsurx]
set_property PACKAGE_PIN E29 [get_ports dsutx]

# UARTS gpio[50 - 63]
set_property IOSTANDARD LVCMOS33 [get_ports uart*]
set_property PACKAGE_PIN E30 [get_ports {uart_rxd[4]}]
set_property PACKAGE_PIN H24 [get_ports {uart_txd[4]}]
set_property PACKAGE_PIN H25 [get_ports {uart_rxd[3]}]
set_property PACKAGE_PIN G28 [get_ports {uart_txd[3]}]
set_property PACKAGE_PIN F28 [get_ports {uart_rxd[2]}]
set_property PACKAGE_PIN G27 [get_ports {uart_txd[2]}]
set_property PACKAGE_PIN F27 [get_ports {uart_ctsn[1]}]
set_property PACKAGE_PIN G29 [get_ports {uart_rtsn[1]}]
set_property PACKAGE_PIN F30 [get_ports {uart_rxd[1]}]
set_property PACKAGE_PIN H26 [get_ports {uart_txd[1]}]
set_property PACKAGE_PIN H27 [get_ports {uart_ctsn[0]}]
set_property PACKAGE_PIN H30 [get_ports {uart_rtsn[0]}]
set_property PACKAGE_PIN G30 [get_ports {uart_rxd[0]}]
set_property PACKAGE_PIN G25 [get_ports {uart_txd[0]}]



# interface pins for user Switches
# 0-3 are dip switch, 4 & 5 are push buttons

set_property IOSTANDARD LVCMOS18 [get_ports switch*]



set_property PACKAGE_PIN AK16 [get_ports {switch[0]}]
set_property PACKAGE_PIN AK15 [get_ports {switch[1]}]
set_property PACKAGE_PIN AG15 [get_ports {switch[2]}]
set_property PACKAGE_PIN AH15 [get_ports {switch[3]}]
set_property PACKAGE_PIN AH16 [get_ports {switch[4]}]
set_property PACKAGE_PIN AJ16 [get_ports {switch[5]}]




## interface pins for USB ULPI port
#
#set_property IOSTANDARD LVCMOS18 [get_ports usb_*]
#
#set_property PACKAGE_PIN AF18 [get_ports {usb_clk}]
#set_property PACKAGE_PIN AJ19 [get_ports {usb_d[0]}]
#set_property PACKAGE_PIN AG14 [get_ports {usb_d[1]}]
#set_property PACKAGE_PIN AF15 [get_ports {usb_d[2]}]
#set_property PACKAGE_PIN AE16 [get_ports {usb_d[3]}]
#set_property PACKAGE_PIN AF16 [get_ports {usb_d[4]}]
#set_property PACKAGE_PIN AD19 [get_ports {usb_d[5]}]
#set_property PACKAGE_PIN AH19 [get_ports {usb_d[6]}]
#set_property PACKAGE_PIN AG19 [get_ports {usb_d[7]}]
#set_property PACKAGE_PIN AJ18 [get_ports {usb_dir}]
#set_property PACKAGE_PIN AJ17 [get_ports {usb_next}]
#set_property PACKAGE_PIN AK19 [get_ports {usb_resetn}]
#set_property PACKAGE_PIN AK18 [get_ports {usb_stp}]


# interface pins for I2C port

set_property IOSTANDARD LVCMOS33 [get_ports iic*]

set_property PACKAGE_PIN R24 [get_ports iic_scl]
set_property PACKAGE_PIN T20 [get_ports iic_sda]


# reserved pins - do not assign

#set_property PACKAGE_PIN T14 [get_ports {v_n}]
#set_property PACKAGE_PIN R15 [get_ports {v_p}]
#set_property PACKAGE_PIN K10 [get_ports {prog_b}]
#set_property PACKAGE_PIN R23 [get_ports {pudc_b}]
#set_property PACKAGE_PIN B10 [get_ports {netr197_[1]}]
#set_property PACKAGE_PIN A10 [get_ports {init_b}]
#set_property PACKAGE_PIN AB5 [get_ports {m0}]
#set_property PACKAGE_PIN AB2 [get_ports {m1}]
#set_property PACKAGE_PIN AB1 [get_ports {m2}]
#set_property PACKAGE_PIN M10 [get_ports {done}]
#set_property PACKAGE_PIN E10 [get_ports {fpga_tck}]
#set_property PACKAGE_PIN H10 [get_ports {fpga_tdi}]
#set_property PACKAGE_PIN G10 [get_ports {fpga_tdo}]
#set_property PACKAGE_PIN F10 [get_ports {fpga_tms}]
#set_property PACKAGE_PIN AE19 [get_ports {nc[0]}]
#set_property PACKAGE_PIN AH17 [get_ports {nc[1]}]
#set_property PACKAGE_PIN AG18 [get_ports {nc[2]}]
#set_property PACKAGE_PIN AD18 [get_ports {nc[3]}]
#set_property PACKAGE_PIN AE18 [get_ports {nc[4]}]
#set_property PACKAGE_PIN AD17 [get_ports {nc[5]}]
#set_property PACKAGE_PIN AD16 [get_ports {nc[6]}]
#set_property PACKAGE_PIN AA18 [get_ports {nc[7]}]
#set_property PACKAGE_PIN AB18 [get_ports {nc[8]}]
#set_property PACKAGE_PIN AB19 [get_ports {nc[9]}]
#set_property PACKAGE_PIN AC19 [get_ports {nc[10]}]
#set_property PACKAGE_PIN AC22 [get_ports {nc[11]}]
#set_property PACKAGE_PIN AD22 [get_ports {nc[12]}]
#set_property PACKAGE_PIN AC24 [get_ports {nc[13]}]
#set_property PACKAGE_PIN AD24 [get_ports {nc[14]}]
#set_property PACKAGE_PIN AD21 [get_ports {nc[15]}]
#set_property PACKAGE_PIN AE21 [get_ports {nc[16]}]
#set_property PACKAGE_PIN AF23 [get_ports {nc[17]}]
#set_property PACKAGE_PIN AE24 [get_ports {nc[18]}]
#set_property PACKAGE_PIN AH25 [get_ports {nc[19]}]
#set_property PACKAGE_PIN AF20 [get_ports {nc[20]}]
#set_property PACKAGE_PIN AF21 [get_ports {nc[21]}]
#set_property PACKAGE_PIN AG22 [get_ports {nc[22]}]
#set_property PACKAGE_PIN AH22 [get_ports {nc[23]}]
#set_property PACKAGE_PIN AJ22 [get_ports {nc[24]}]
#set_property PACKAGE_PIN AJ23 [get_ports {nc[25]}]
#set_property PACKAGE_PIN AG20 [get_ports {nc[26]}]
#set_property PACKAGE_PIN P19 [get_ports {nc[27]}]
#set_property PACKAGE_PIN G12 [get_ports {nc[28]}]
#set_property PACKAGE_PIN B25 [get_ports {nc[29]}]
#set_property PACKAGE_PIN G19 [get_ports {nc[30]}]
#set_property PACKAGE_PIN E18 [get_ports {nc[31]}]
#set_property PACKAGE_PIN F16 [get_ports {nc[32]}]
#set_property PACKAGE_PIN AG10 [get_ports {nc[33]}]
#set_property PACKAGE_PIN AH10 [get_ports {nc[34]}]
#set_property PACKAGE_PIN AE10 [get_ports {nc[35]}]
#set_property PACKAGE_PIN AF10 [get_ports {nc[36]}]
#set_property PACKAGE_PIN AJ9 [get_ports {nc[37]}]
#set_property PACKAGE_PIN AK9 [get_ports {nc[38]}]
#set_property PACKAGE_PIN AG9 [get_ports {nc[39]}]
#set_property PACKAGE_PIN AH9 [get_ports {nc[40]}]
#set_property PACKAGE_PIN AK11 [get_ports {nc[41]}]
#set_property PACKAGE_PIN AK10 [get_ports {nc[42]}]
#set_property PACKAGE_PIN AH11 [get_ports {nc[43]}]
#set_property PACKAGE_PIN AJ11 [get_ports {nc[44]}]
#set_property PACKAGE_PIN AE13 [get_ports {nc[45]}]
#set_property PACKAGE_PIN AK14 [get_ports {nc[46]}]
#set_property PACKAGE_PIN AK13 [get_ports {nc[47]}]
#set_property PACKAGE_PIN AH14 [get_ports {nc[48]}]
#set_property PACKAGE_PIN AJ14 [get_ports {nc[49]}]
#set_property PACKAGE_PIN AJ13 [get_ports {nc[50]}]
#set_property PACKAGE_PIN AJ12 [get_ports {nc[51]}]
#set_property PACKAGE_PIN AF12 [get_ports {nc[52]}]
#set_property PACKAGE_PIN AG12 [get_ports {nc[53]}]
#set_property PACKAGE_PIN AG13 [get_ports {nc[54]}]
#set_property PACKAGE_PIN AH12 [get_ports {nc[55]}]
#set_property PACKAGE_PIN AF15 [get_ports {nc[56]}]
#set_property PACKAGE_PIN AG17 [get_ports {nc[57]}]
#set_property PACKAGE_PIN AH6 [get_ports {nc[58]}]
#set_property PACKAGE_PIN AH5 [get_ports {nc[59]}]
#set_property PACKAGE_PIN AH2 [get_ports {nc[60]}]
#set_property PACKAGE_PIN AJ2 [get_ports {nc[61]}]
#set_property PACKAGE_PIN AJ1 [get_ports {nc[62]}]
#set_property PACKAGE_PIN AK1 [get_ports {nc[63]}]
#set_property PACKAGE_PIN AJ3 [get_ports {nc[64]}]
#set_property PACKAGE_PIN AK3 [get_ports {nc[65]}]
#set_property PACKAGE_PIN AF8 [get_ports {nc[66]}]
#set_property PACKAGE_PIN AG8 [get_ports {nc[67]}]
#set_property PACKAGE_PIN AF7 [get_ports {nc[68]}]
#set_property PACKAGE_PIN AG7 [get_ports {nc[69]}]
#set_property PACKAGE_PIN AH7 [get_ports {nc[70]}]
#set_property PACKAGE_PIN AJ7 [get_ports {nc[71]}]
#set_property PACKAGE_PIN AJ6 [get_ports {nc[72]}]
#set_property PACKAGE_PIN AK6 [get_ports {nc[73]}]
#set_property PACKAGE_PIN AJ8 [get_ports {nc[74]}]
#set_property PACKAGE_PIN AK8 [get_ports {nc[75]}]
#set_property PACKAGE_PIN AK5 [get_ports {nc[76]}]
#set_property PACKAGE_PIN AK4 [get_ports {nc[77]}]
#set_property PACKAGE_PIN N7 [get_ports {nc[78]}]
#set_property PACKAGE_PIN G8 [get_ports {nc[79]}]
#set_property PACKAGE_PIN G7 [get_ports {nc[80]}]
#set_property PACKAGE_PIN J8 [get_ports {nc[81]}]
#set_property PACKAGE_PIN J7 [get_ports {nc[82]}]
#set_property PACKAGE_PIN U8 [get_ports {nc[83]}]
#set_property PACKAGE_PIN U7 [get_ports {nc[84]}]
#set_property PACKAGE_PIN E8 [get_ports {nc[85]}]
#set_property PACKAGE_PIN E7 [get_ports {nc[86]}]
#set_property PACKAGE_PIN U4 [get_ports {nc[87]}]
#set_property PACKAGE_PIN U3 [get_ports {nc[88]}]
#set_property PACKAGE_PIN T2 [get_ports {nc[89]}]
#set_property PACKAGE_PIN T1 [get_ports {nc[90]}]
#set_property PACKAGE_PIN M2 [get_ports {nc[91]}]
#set_property PACKAGE_PIN M1 [get_ports {nc[92]}]
#set_property PACKAGE_PIN L4 [get_ports {nc[93]}]
#set_property PACKAGE_PIN L3 [get_ports {nc[94]}]
#set_property PACKAGE_PIN K2 [get_ports {nc[95]}]
#set_property PACKAGE_PIN K1 [get_ports {nc[96]}]
#set_property PACKAGE_PIN J4 [get_ports {nc[97]}]
#set_property PACKAGE_PIN J3 [get_ports {nc[98]}]
#set_property PACKAGE_PIN H2 [get_ports {nc[99]}]
#set_property PACKAGE_PIN H1 [get_ports {nc[100]}]
#set_property PACKAGE_PIN F2 [get_ports {nc[101]}]
#set_property PACKAGE_PIN F1 [get_ports {nc[102]}]
#set_property PACKAGE_PIN Y2 [get_ports {nc[103]}]
#set_property PACKAGE_PIN Y1 [get_ports {nc[104]}]
#set_property PACKAGE_PIN C4 [get_ports {nc[105]}]
#set_property PACKAGE_PIN C3 [get_ports {nc[106]}]
#set_property PACKAGE_PIN V2 [get_ports {nc[107]}]
#set_property PACKAGE_PIN V1 [get_ports {nc[108]}]
#set_property PACKAGE_PIN A4 [get_ports {nc[109]}]
#set_property PACKAGE_PIN A3 [get_ports {nc[110]}]
#set_property PACKAGE_PIN R19 [get_ports {nc[111]}]
#set_property PACKAGE_PIN N8 [get_ports {nc[112]}]


# *** END ***















