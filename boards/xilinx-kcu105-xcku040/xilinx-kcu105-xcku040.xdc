#-----------------------------------------------------------
#                  Constraints                             -
#-----------------------------------------------------------

# --- Define and constrain system clock
create_clock -period 3.332 -name clk300 [get_ports clk300p]
set_propagated_clock [get_clocks clk300]

# --- False paths
set_false_path -to [get_ports led*]
set_false_path -from [get_ports reset]
set_false_path -from [get_ports button*]
set_false_path -from [get_ports switch*]

 --- Clock Domain Crossing (in case of the DDR4 MIG)
set_false_path -from [get_clocks mmcm_clkout0] -to [get_clocks -include_generated_clocks mmcm_clkout1]
set_false_path -from [get_clocks mmcm_clkout1] -to [get_clocks -include_generated_clocks mmcm_clkout0]

# --- Ethernet clocks
#create_clock -period 8.000 -name gtrefclk [get_pins -hier *ibufds_gtrefclk/O]
#set_propagated_clock [get_clocks gtrefclk]
#create_clock -period 16.000 -name rxoutclk [get_pins eth0.sgmii0/core_wrapper/inst/transceiver_inst/sgmii_gt_i/inst/rxoutclk_out*] 

#-----------------------------------------------------------
#                  Pin and IO Property                     -
#-----------------------------------------------------------

# --- Clocks -----------------------------------------------
set_property ODT RTT_48 [get_ports clk300n]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports clk300n]
set_property PACKAGE_PIN AK16 [get_ports clk300n]
set_property PACKAGE_PIN AK17 [get_ports clk300p]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports clk300p]
set_property ODT RTT_48 [get_ports clk300p]

# --- Reset ------------------------------------------------
set_property PACKAGE_PIN AN8 [get_ports reset]
set_property IOSTANDARD LVCMOS18 [get_ports reset]

# --- Switches ---------------------------------------------
set_property PACKAGE_PIN AN16 [get_ports {switch[0]}]
set_property PACKAGE_PIN AN19 [get_ports {switch[1]}]
set_property PACKAGE_PIN AP18 [get_ports {switch[2]}]
set_property PACKAGE_PIN AN14 [get_ports {switch[3]}]

set_property IOSTANDARD LVCMOS12 [get_ports switch*]

# --- LEDs -------------------------------------------------
set_property PACKAGE_PIN AP8 [get_ports {led[0]}]
set_property PACKAGE_PIN H23 [get_ports {led[1]}]
set_property PACKAGE_PIN P20 [get_ports {led[2]}]
set_property PACKAGE_PIN P21 [get_ports {led[3]}]
set_property PACKAGE_PIN N22 [get_ports {led[4]}]
set_property PACKAGE_PIN M22 [get_ports {led[5]}]
set_property PACKAGE_PIN R23 [get_ports {led[6]}]
set_property PACKAGE_PIN P23 [get_ports {led[7]}]

set_property IOSTANDARD LVCMOS18 [get_ports led*]

# --- Push Buttons -----------------------------------------
set_property PACKAGE_PIN AE10 [get_ports {button[0]}]
set_property PACKAGE_PIN AE8 [get_ports {button[1]}]
set_property PACKAGE_PIN AD10 [get_ports {button[2]}]
set_property PACKAGE_PIN AF8 [get_ports {button[3]}]
set_property PACKAGE_PIN AF9 [get_ports {button[4]}]

set_property IOSTANDARD LVCMOS18 [get_ports button*]

# --- GPIO PMOD0 -------------------------------------------
set_property PACKAGE_PIN AK25 [get_ports {gpio[0]}]
set_property PACKAGE_PIN AN21 [get_ports {gpio[1]}]
set_property PACKAGE_PIN AH18 [get_ports {gpio[2]}]
set_property PACKAGE_PIN AM19 [get_ports {gpio[3]}]
set_property PACKAGE_PIN AE26 [get_ports {gpio[4]}]
set_property PACKAGE_PIN AF25 [get_ports {gpio[5]}]
set_property PACKAGE_PIN AE21 [get_ports {gpio[6]}]
set_property PACKAGE_PIN AM17 [get_ports {gpio[7]}]

set_property UNAVAILABLE_DURING_CALIBRATION true [get_ports {gpio[2]}]
set_property UNAVAILABLE_DURING_CALIBRATION true [get_ports {gpio[8]}]


# --- GPIO PMOD1 -------------------------------------------
set_property PACKAGE_PIN AL14 [get_ports {gpio[8]}]
set_property PACKAGE_PIN AM14 [get_ports {gpio[9]}]
set_property PACKAGE_PIN AP16 [get_ports {gpio[10]}]
set_property PACKAGE_PIN AP15 [get_ports {gpio[11]}]
set_property PACKAGE_PIN AM16 [get_ports {gpio[12]}]
set_property PACKAGE_PIN AM15 [get_ports {gpio[13]}]
set_property PACKAGE_PIN AN18 [get_ports {gpio[14]}]
set_property PACKAGE_PIN AN17 [get_ports {gpio[15]}]

set_property IOSTANDARD LVCMOS12 [get_ports gpio*]

# --- I2C --------------------------------------------------
set_property PACKAGE_PIN J24 [get_ports iic_scl]
set_property PACKAGE_PIN J25 [get_ports iic_sda]
set_property PACKAGE_PIN AP10 [get_ports iic_mreset]

set_property IOSTANDARD LVCMOS18 [get_ports iic*]

# --- Ethernet ---------------------------------------------
set_property PACKAGE_PIN N26 [get_ports gtrefclk_n]
set_property PACKAGE_PIN P26 [get_ports gtrefclk_p]
set_property PACKAGE_PIN K25 [get_ports eint]
set_property PACKAGE_PIN L25 [get_ports emdc]
set_property PACKAGE_PIN H26 [get_ports emdio]
set_property PACKAGE_PIN J23 [get_ports erst]
set_property PACKAGE_PIN P25 [get_ports rxn]
set_property PACKAGE_PIN P24 [get_ports rxp]
set_property PACKAGE_PIN M24 [get_ports txn]
set_property PACKAGE_PIN N24 [get_ports txp]

set_property IOSTANDARD LVCMOS18 [get_ports eint]
set_property IOSTANDARD LVCMOS18 [get_ports emdc]
set_property IOSTANDARD LVCMOS18 [get_ports emdio]
set_property IOSTANDARD LVCMOS18 [get_ports erst]

set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports rxn]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports rxp]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports txn]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports txp]
set_property IOSTANDARD LVDS_25        [get_ports gtrefclk_n]
set_property IOSTANDARD LVDS_25        [get_ports gtrefclk_p]

# 625 MHz ref clock from SGMII PHY
create_clock -period 1.600 -name gtrefclk [get_ports gtrefclk_p]

set_false_path -to [get_pins -hier -filter {name =~  *core_resets_i/rst_dly_reg*/PRE}]
set_property CLOCK_DELAY_GROUP cdg0 [get_nets -of [get_pins -hier -filter {name =~  *core_clocking_i/clk312_buf/O}]]
set_property CLOCK_DELAY_GROUP cdg0 [get_nets -of [get_pins -hier -filter {name =~  *core_clocking_i/clk625_buf/O}]]
  
# false path constraints to async inputs coming directly to synchronizer
set_false_path -to [get_pins -hier -filter {name =~ *SYNC_*/data_sync*/D }]
set_false_path -to [get_pins -hier -filter {name =~ *SYNC_*/reset_sync*/PRE }]

set_false_path -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_10_to_1_ser8_i/gb0/*_dom_ch_reg/D }]
set_false_path -to [get_pins -hier -filter {name =~  */lvds_transceiver_mw/serdes_1_to_10_ser8_i/rxclk_r_reg/D}]

set_false_path -from [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/gb0/loop2[*].ram_ins*/RAM*/CLK }] -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/gb0/loop0[*].dataout_reg[*]/D }]
set_false_path -from [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_10_to_1_ser8_i/gb0/loop2[*].ram_ins*/RAM*/CLK }] -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_10_to_1_ser8_i/gb0/loop0[*].dataout_reg[*]/D }]
set_false_path -from [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/gb0/loop2[*].ram_ins*/RAM*/CLK }] -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/rxdh*/D }]
set_false_path -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/iserdes_m/RST }]
set_false_path -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/iserdes_s/RST }]
set_false_path -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_10_to_1_ser8_i/oserdes_m/RST }]
set_false_path -to [get_pins -hier -filter {name =~ */*sync_speed_10*/data_sync*/D }]
set_false_path -to [get_pins -hier -filter {name =~ */*gen_sync_reset/reset_sync*/PRE }]
set_false_path -to [get_pins -hier -filter { name =~ */*reset_sync_inter*/*sync*/PRE } ]
set_false_path -to [get_pins -hier -filter { name =~ */*reset_sync_output_cl*/*sync*/PRE } ]
set_false_path -to [get_pins -hier -filter { name =~ */*reset_sync_rxclk_div*/*sync*/PRE } ]
set_false_path -to [get_pins -hier -filter { name =~ */*reset_rxclk_div*/*sync*/PRE } ]

set_false_path -from [get_pins -hier -filter {name =~  */lvds_transceiver_mw/serdes_10_to_1_ser8_i/gb0/read_enable_reg/C}] -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_10_to_1_ser8_i/gb0/read_enable_dom_ch_reg/D}] 
set_false_path -from [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/gb0/read_enable_reg/C}] -to [get_pins -hier -filter {name =~ */lvds_transceiver_mw/serdes_1_to_10_ser8_i/gb0/read_enabler_reg/D}]

# Without MIG
set_max_delay -from [get_clocks clk_nobuf] -to   [get_clocks clk125*] 12.000
set_max_delay -to   [get_clocks clk_nobuf] -from [get_clocks clk125*] 12.000

# With MIG
set_max_delay -from [get_clocks mmcm_clkout*] -to   [get_clocks clk125*] 12.000
set_max_delay -to   [get_clocks mmcm_clkout*] -from [get_clocks clk125*] 12.000

# False paths
## WARNING: [Route 35-468] The router encountered 122 pins that are both setup-critical and hold-critical and tried to fix hold violations at the expense of setup slack. Such pins are:
##        eth0.sgmii0/userclk2_rst/syncrregs.gmiimode1.r[rxd][3]_i_1/I2
##        eth0.sgmii0/userclk2_rst/rrx[gmii_rxd][0]_i_1/I1
##        eth0.sgmii0/userclk2_rst/rrx[gmii_rxd][1]_i_1/I1
set_false_path -from [get_clocks clk_nobuf]    -to [get_pins -hier -filter {name =~ *sgmii*/userclk2_rst/* }]
set_false_path -from [get_clocks mmcm_clkout*] -to [get_pins -hier -filter {name =~ *sgmii*/userclk2_rst/* }]

# --- USB UART ---------------------------------------------
set_property PACKAGE_PIN L23 [get_ports dsuctsn]
set_property PACKAGE_PIN K27 [get_ports dsurtsn]
set_property PACKAGE_PIN G25 [get_ports dsurx]
set_property PACKAGE_PIN K26 [get_ports dsutx]

set_property IOSTANDARD LVCMOS18 [get_ports dsu*]

# --- DDR4 (MIG) --------------------------------------------
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_dq[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_dm_n[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_dqs_c[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_dqs_t[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_act_n}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_odt[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_ck_t[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_ck_c[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_addr[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_ba[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_bg[*]}]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports {ddr4_cke[*]}]

set_property DRIVE 8 [get_ports ddr4_reset_n]

set_property SLEW FAST [get_ports {ddr4_addr[*]}]
set_property SLEW FAST [get_ports {ddr4_act_n}]
set_property SLEW FAST [get_ports {ddr4_ba[*]}]
set_property SLEW FAST [get_ports {ddr4_bg[*]}]
set_property SLEW FAST [get_ports {ddr4_cke[*]}]
set_property SLEW FAST [get_ports {ddr4_ck_c[*]}]
set_property SLEW FAST [get_ports {ddr4_ck_t[*]}]
set_property SLEW FAST [get_ports {ddr4_odt[*]}]
set_property SLEW FAST [get_ports {ddr4_dqs_t[*]}]
set_property SLEW FAST [get_ports {ddr4_dqs_c[*]}]
set_property SLEW FAST [get_ports {ddr4_cs_n[*]}]
set_property SLEW FAST [get_ports {ddr4_dm_n[*]}]

set_property SLEW FAST [get_ports {ddr4_dq[0]}]
set_property SLEW FAST [get_ports {ddr4_dq[1]}]
set_property SLEW FAST [get_ports {ddr4_dq[2]}]
set_property SLEW FAST [get_ports {ddr4_dq[3]}]
set_property SLEW FAST [get_ports {ddr4_dq[4]}]
set_property SLEW FAST [get_ports {ddr4_dq[5]}]
set_property SLEW FAST [get_ports {ddr4_dq[6]}]
set_property SLEW FAST [get_ports {ddr4_dq[7]}]
set_property SLEW FAST [get_ports {ddr4_dq[8]}]
set_property SLEW FAST [get_ports {ddr4_dq[9]}]
set_property SLEW FAST [get_ports {ddr4_dq[10]}]
set_property SLEW FAST [get_ports {ddr4_dq[11]}]
set_property SLEW FAST [get_ports {ddr4_dq[12]}]
set_property SLEW FAST [get_ports {ddr4_dq[13]}]
set_property SLEW FAST [get_ports {ddr4_dq[14]}]
set_property SLEW FAST [get_ports {ddr4_dq[15]}]
set_property SLEW FAST [get_ports {ddr4_dq[16]}]
set_property SLEW FAST [get_ports {ddr4_dq[17]}]
set_property SLEW FAST [get_ports {ddr4_dq[18]}]
set_property SLEW FAST [get_ports {ddr4_dq[19]}]
set_property SLEW FAST [get_ports {ddr4_dq[20]}]
set_property SLEW FAST [get_ports {ddr4_dq[21]}]
set_property SLEW FAST [get_ports {ddr4_dq[22]}]
set_property SLEW FAST [get_ports {ddr4_dq[23]}]
set_property SLEW FAST [get_ports {ddr4_dq[24]}]
set_property SLEW FAST [get_ports {ddr4_dq[25]}]
set_property SLEW FAST [get_ports {ddr4_dq[26]}]
set_property SLEW FAST [get_ports {ddr4_dq[27]}]
set_property SLEW FAST [get_ports {ddr4_dq[28]}]
set_property SLEW FAST [get_ports {ddr4_dq[29]}]
set_property SLEW FAST [get_ports {ddr4_dq[30]}]
set_property SLEW FAST [get_ports {ddr4_dq[31]}]
set_property SLEW FAST [get_ports {ddr4_dq[32]}]
set_property SLEW FAST [get_ports {ddr4_dq[33]}]
set_property SLEW FAST [get_ports {ddr4_dq[34]}]
set_property SLEW FAST [get_ports {ddr4_dq[35]}]
set_property SLEW FAST [get_ports {ddr4_dq[36]}]
set_property SLEW FAST [get_ports {ddr4_dq[37]}]
set_property SLEW FAST [get_ports {ddr4_dq[38]}]
set_property SLEW FAST [get_ports {ddr4_dq[39]}]
set_property SLEW FAST [get_ports {ddr4_dq[40]}]
set_property SLEW FAST [get_ports {ddr4_dq[41]}]
set_property SLEW FAST [get_ports {ddr4_dq[42]}]
set_property SLEW FAST [get_ports {ddr4_dq[43]}]
set_property SLEW FAST [get_ports {ddr4_dq[44]}]
set_property SLEW FAST [get_ports {ddr4_dq[45]}]
set_property SLEW FAST [get_ports {ddr4_dq[46]}]
set_property SLEW FAST [get_ports {ddr4_dq[47]}]
set_property SLEW FAST [get_ports {ddr4_dq[48]}]
set_property SLEW FAST [get_ports {ddr4_dq[49]}]
set_property SLEW FAST [get_ports {ddr4_dq[50]}]
set_property SLEW FAST [get_ports {ddr4_dq[51]}]
set_property SLEW FAST [get_ports {ddr4_dq[52]}]
set_property SLEW FAST [get_ports {ddr4_dq[53]}]
set_property SLEW FAST [get_ports {ddr4_dq[54]}]
set_property SLEW FAST [get_ports {ddr4_dq[55]}]
set_property SLEW FAST [get_ports {ddr4_dq[56]}]
set_property SLEW FAST [get_ports {ddr4_dq[57]}]
set_property SLEW FAST [get_ports {ddr4_dq[58]}]
set_property SLEW FAST [get_ports {ddr4_dq[59]}]
set_property SLEW FAST [get_ports {ddr4_dq[60]}]
set_property SLEW FAST [get_ports {ddr4_dq[61]}]
set_property SLEW FAST [get_ports {ddr4_dq[62]}]
set_property SLEW FAST [get_ports {ddr4_dq[63]}]

set_property IBUF_LOW_PWR FALSE [get_ports {ddr4_dq[*] ddr4_dqs_t[*] ddr4_dqs_c[*]}]
set_property IBUF_LOW_PWR FALSE  [get_ports {ddr4_dm_n[*]}]

set_property ODT RTT_40  [get_ports {ddr4_dq[*] ddr4_dqs_t[*] ddr4_dqs_c[*]}]
set_property ODT RTT_40  [get_ports {ddr4_dm_n[*]}]

set_property EQUALIZATION EQ_LEVEL2 [get_ports {ddr4_dq[*] ddr4_dqs_t[*] ddr4_dqs_c[*]}]
set_property EQUALIZATION EQ_LEVEL2 [get_ports {ddr4_dm_n[*]}]

set_property PRE_EMPHASIS RDRV_240 [get_ports {ddr4_dq[*] ddr4_dqs_t[*] ddr4_dqs_c[*]}]
set_property PRE_EMPHASIS RDRV_240 [get_ports {ddr4_dm_n[*]}]

set_property DATA_RATE SDR  [get_ports {ddr4_cs_n[*]}]
set_property DATA_RATE SDR  [get_ports {ddr4_addr[*] ddr4_act_n ddr4_ba[*] ddr4_bg[*] ddr4_cke[*] ddr4_odt[*] }]

set_property DATA_RATE DDR [get_ports {ddr4_dm_n[*]}]
set_property DATA_RATE DDR  [get_ports {ddr4_dq[*] ddr4_dqs_t[*] ddr4_dqs_c[*] ddr4_ck_t[*] ddr4_ck_c[*]}]

set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[0]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[1]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[2]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[3]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[4]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[5]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[6]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[7]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[8]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[9]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[10]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[11]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[12]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[13]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[14]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[15]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[16]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[17]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[18]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[19]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[20]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[21]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[22]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[23]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[24]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[25]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[26]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[27]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[28]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[29]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[30]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[31]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[32]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[33]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[34]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[35]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[36]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[37]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[38]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[39]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[40]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[41]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[42]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[43]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[44]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[45]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[46]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[47]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[48]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[49]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[50]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[51]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[52]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[53]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[54]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[55]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[56]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[57]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[58]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[59]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[60]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[61]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[62]}]
set_property IOSTANDARD POD12_DCI [get_ports {ddr4_dq[63]}]

set_property PACKAGE_PIN AE23 [get_ports {ddr4_dq[0]}]
set_property PACKAGE_PIN AG20 [get_ports {ddr4_dq[1]}]
set_property PACKAGE_PIN AF22 [get_ports {ddr4_dq[2]}]
set_property PACKAGE_PIN AF20 [get_ports {ddr4_dq[3]}]
set_property PACKAGE_PIN AE22 [get_ports {ddr4_dq[4]}]
set_property PACKAGE_PIN AD20 [get_ports {ddr4_dq[5]}]
set_property PACKAGE_PIN AG22 [get_ports {ddr4_dq[6]}]
set_property PACKAGE_PIN AE20 [get_ports {ddr4_dq[7]}]
set_property PACKAGE_PIN AJ24 [get_ports {ddr4_dq[8]}]
set_property PACKAGE_PIN AG24 [get_ports {ddr4_dq[9]}]
set_property PACKAGE_PIN AJ23 [get_ports {ddr4_dq[10]}]
set_property PACKAGE_PIN AF23 [get_ports {ddr4_dq[11]}]
set_property PACKAGE_PIN AH23 [get_ports {ddr4_dq[12]}]
set_property PACKAGE_PIN AF24 [get_ports {ddr4_dq[13]}]
set_property PACKAGE_PIN AH22 [get_ports {ddr4_dq[14]}]
set_property PACKAGE_PIN AG25 [get_ports {ddr4_dq[15]}]
set_property PACKAGE_PIN AL22 [get_ports {ddr4_dq[16]}]
set_property PACKAGE_PIN AL25 [get_ports {ddr4_dq[17]}]
set_property PACKAGE_PIN AM20 [get_ports {ddr4_dq[18]}]
set_property PACKAGE_PIN AK23 [get_ports {ddr4_dq[19]}]
set_property PACKAGE_PIN AK22 [get_ports {ddr4_dq[20]}]
set_property PACKAGE_PIN AL24 [get_ports {ddr4_dq[21]}]
set_property PACKAGE_PIN AL20 [get_ports {ddr4_dq[22]}]
set_property PACKAGE_PIN AL23 [get_ports {ddr4_dq[23]}]
set_property PACKAGE_PIN AM24 [get_ports {ddr4_dq[24]}]
set_property PACKAGE_PIN AN23 [get_ports {ddr4_dq[25]}]
set_property PACKAGE_PIN AN24 [get_ports {ddr4_dq[26]}]
set_property PACKAGE_PIN AP23 [get_ports {ddr4_dq[27]}]
set_property PACKAGE_PIN AP25 [get_ports {ddr4_dq[28]}]
set_property PACKAGE_PIN AN22 [get_ports {ddr4_dq[29]}]
set_property PACKAGE_PIN AP24 [get_ports {ddr4_dq[30]}]
set_property PACKAGE_PIN AM22 [get_ports {ddr4_dq[31]}]
set_property PACKAGE_PIN AH28 [get_ports {ddr4_dq[32]}]
set_property PACKAGE_PIN AK26 [get_ports {ddr4_dq[33]}]
set_property PACKAGE_PIN AK28 [get_ports {ddr4_dq[34]}]
set_property PACKAGE_PIN AM27 [get_ports {ddr4_dq[35]}]
set_property PACKAGE_PIN AJ28 [get_ports {ddr4_dq[36]}]
set_property PACKAGE_PIN AH27 [get_ports {ddr4_dq[37]}]
set_property PACKAGE_PIN AK27 [get_ports {ddr4_dq[38]}]
set_property PACKAGE_PIN AM26 [get_ports {ddr4_dq[39]}]
set_property PACKAGE_PIN AL30 [get_ports {ddr4_dq[40]}]
set_property PACKAGE_PIN AP29 [get_ports {ddr4_dq[41]}]
set_property PACKAGE_PIN AM30 [get_ports {ddr4_dq[42]}]
set_property PACKAGE_PIN AN28 [get_ports {ddr4_dq[43]}]
set_property PACKAGE_PIN AL29 [get_ports {ddr4_dq[44]}]
set_property PACKAGE_PIN AP28 [get_ports {ddr4_dq[45]}]
set_property PACKAGE_PIN AM29 [get_ports {ddr4_dq[46]}]
set_property PACKAGE_PIN AN27 [get_ports {ddr4_dq[47]}]
set_property PACKAGE_PIN AH31 [get_ports {ddr4_dq[48]}]
set_property PACKAGE_PIN AH32 [get_ports {ddr4_dq[49]}]
set_property PACKAGE_PIN AJ34 [get_ports {ddr4_dq[50]}]
set_property PACKAGE_PIN AK31 [get_ports {ddr4_dq[51]}]
set_property PACKAGE_PIN AJ31 [get_ports {ddr4_dq[52]}]
set_property PACKAGE_PIN AJ30 [get_ports {ddr4_dq[53]}]
set_property PACKAGE_PIN AH34 [get_ports {ddr4_dq[54]}]
set_property PACKAGE_PIN AK32 [get_ports {ddr4_dq[55]}]
set_property PACKAGE_PIN AN33 [get_ports {ddr4_dq[56]}]
set_property PACKAGE_PIN AP33 [get_ports {ddr4_dq[57]}]
set_property PACKAGE_PIN AM34 [get_ports {ddr4_dq[58]}]
set_property PACKAGE_PIN AP31 [get_ports {ddr4_dq[59]}]
set_property PACKAGE_PIN AM32 [get_ports {ddr4_dq[60]}]
set_property PACKAGE_PIN AN31 [get_ports {ddr4_dq[61]}]
set_property PACKAGE_PIN AL34 [get_ports {ddr4_dq[62]}]
set_property PACKAGE_PIN AN32 [get_ports {ddr4_dq[63]}]

set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_addr*]

set_property PACKAGE_PIN AE17 [get_ports {ddr4_addr[0]}]
set_property PACKAGE_PIN AH17 [get_ports {ddr4_addr[1]}]
set_property PACKAGE_PIN AE18 [get_ports {ddr4_addr[2]}]
set_property PACKAGE_PIN AJ15 [get_ports {ddr4_addr[3]}]
set_property PACKAGE_PIN AG16 [get_ports {ddr4_addr[4]}]
set_property PACKAGE_PIN AL17 [get_ports {ddr4_addr[5]}]
set_property PACKAGE_PIN AK18 [get_ports {ddr4_addr[6]}]
set_property PACKAGE_PIN AG17 [get_ports {ddr4_addr[7]}]
set_property PACKAGE_PIN AF18 [get_ports {ddr4_addr[8]}]
set_property PACKAGE_PIN AH19 [get_ports {ddr4_addr[9]}]
set_property PACKAGE_PIN AF15 [get_ports {ddr4_addr[10]}]
set_property PACKAGE_PIN AD19 [get_ports {ddr4_addr[11]}]
set_property PACKAGE_PIN AJ14 [get_ports {ddr4_addr[12]}]
set_property PACKAGE_PIN AG19 [get_ports {ddr4_addr[13]}]

set_property PACKAGE_PIN AD16 [get_ports ddr4_we_n]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_we_n]
set_property PACKAGE_PIN AG14 [get_ports ddr4_cas_n]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_cas_n]
set_property PACKAGE_PIN AF14 [get_ports ddr4_ras_n]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_ras_n]

set_property PACKAGE_PIN AF17 [get_ports {ddr4_ba[0]}]
set_property IOSTANDARD SSTL12_DCI [get_ports {ddr4_ba[0]}]
set_property PACKAGE_PIN AL15 [get_ports {ddr4_ba[1]}]
set_property IOSTANDARD SSTL12_DCI [get_ports {ddr4_ba[1]}]

set_property PACKAGE_PIN AG15 [get_ports {ddr4_bg[0]}]
set_property IOSTANDARD SSTL12_DCI [get_ports {ddr4_bg[0]}]

set_property IOSTANDARD POD12_DCI [get_ports ddr4_dm_n*]

set_property PACKAGE_PIN AD21 [get_ports {ddr4_dm_n[0]}]
set_property PACKAGE_PIN AE25 [get_ports {ddr4_dm_n[1]}]
set_property PACKAGE_PIN AJ21 [get_ports {ddr4_dm_n[2]}]
set_property PACKAGE_PIN AM21 [get_ports {ddr4_dm_n[3]}]
set_property PACKAGE_PIN AH26 [get_ports {ddr4_dm_n[4]}]
set_property PACKAGE_PIN AN26 [get_ports {ddr4_dm_n[5]}]
set_property PACKAGE_PIN AJ29 [get_ports {ddr4_dm_n[6]}]
set_property PACKAGE_PIN AL32 [get_ports {ddr4_dm_n[7]}]

set_property IOSTANDARD DIFF_POD12_DCI [get_ports ddr4_dqs_c*]
set_property IOSTANDARD DIFF_POD12_DCI [get_ports ddr4_dqs_t*]

set_property PACKAGE_PIN AH21 [get_ports {ddr4_dqs_c[0]}]
set_property PACKAGE_PIN AG21 [get_ports {ddr4_dqs_t[0]}]
set_property PACKAGE_PIN AJ25 [get_ports {ddr4_dqs_c[1]}]
set_property PACKAGE_PIN AH24 [get_ports {ddr4_dqs_t[1]}]
set_property PACKAGE_PIN AK20 [get_ports {ddr4_dqs_c[2]}]
set_property PACKAGE_PIN AJ20 [get_ports {ddr4_dqs_t[2]}]
set_property PACKAGE_PIN AP21 [get_ports {ddr4_dqs_c[3]}]
set_property PACKAGE_PIN AP20 [get_ports {ddr4_dqs_t[3]}]
set_property PACKAGE_PIN AL28 [get_ports {ddr4_dqs_c[4]}]
set_property PACKAGE_PIN AL27 [get_ports {ddr4_dqs_t[4]}]
set_property PACKAGE_PIN AP30 [get_ports {ddr4_dqs_c[5]}]
set_property PACKAGE_PIN AN29 [get_ports {ddr4_dqs_t[5]}]
set_property PACKAGE_PIN AJ33 [get_ports {ddr4_dqs_c[6]}]
set_property PACKAGE_PIN AH33 [get_ports {ddr4_dqs_t[6]}]
set_property PACKAGE_PIN AP34 [get_ports {ddr4_dqs_c[7]}]
set_property PACKAGE_PIN AN34 [get_ports {ddr4_dqs_t[7]}]

set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports {ddr4_ck_c[0]}]
set_property PACKAGE_PIN AE15 [get_ports {ddr4_ck_c[0]}]
set_property PACKAGE_PIN AE16 [get_ports {ddr4_ck_t[0]}]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports {ddr4_ck_t[0]}]
set_property PACKAGE_PIN AD15 [get_ports {ddr4_cke[0]}]
set_property IOSTANDARD SSTL12_DCI [get_ports {ddr4_cke[0]}]

set_property PACKAGE_PIN AH14 [get_ports ddr4_act_n]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_act_n]
set_property PACKAGE_PIN AJ16 [get_ports ddr4_alert_n]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_alert_n]
set_property PACKAGE_PIN AJ18 [get_ports {ddr4_odt[0]}]
set_property IOSTANDARD SSTL12_DCI [get_ports {ddr4_odt[0]}]
set_property PACKAGE_PIN AD18 [get_ports ddr4_par]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_par]
set_property PACKAGE_PIN AH16 [get_ports ddr4_ten]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_ten]
set_property PACKAGE_PIN AL19 [get_ports {ddr4_cs_n[0]}]
set_property IOSTANDARD SSTL12_DCI [get_ports {ddr4_cs_n[0]}]
set_property PACKAGE_PIN AL18 [get_ports ddr4_reset_n]
set_property IOSTANDARD LVCMOS12 [get_ports ddr4_reset_n]

# --- FMC (SpaceWire) ---------------------------------------
set_property PACKAGE_PIN G9 [get_ports spw_din_p[1]]
set_property IOSTANDARD LVDS [get_ports spw_din_p[1]]
set_property PACKAGE_PIN F9 [get_ports spw_din_n[1]]
set_property IOSTANDARD LVDS [get_ports spw_din_n[1]]
set_property PACKAGE_PIN E22 [get_ports spw_sin_p[1]]
set_property IOSTANDARD LVDS [get_ports spw_sin_p[1]]
set_property PACKAGE_PIN E23 [get_ports spw_sin_n[1]]
set_property IOSTANDARD LVDS [get_ports spw_sin_n[1]]
set_property PACKAGE_PIN H11 [get_ports spw_din_p[2]]
set_property IOSTANDARD LVDS [get_ports spw_din_p[2]]
set_property PACKAGE_PIN G11 [get_ports spw_din_n[2]]
set_property IOSTANDARD LVDS [get_ports spw_din_n[2]]
set_property PACKAGE_PIN D24 [get_ports spw_sin_p[2]]
set_property IOSTANDARD LVDS [get_ports spw_sin_p[2]]
set_property PACKAGE_PIN C24 [get_ports spw_sin_n[2]]
set_property IOSTANDARD LVDS [get_ports spw_sin_n[2]]

set_property PACKAGE_PIN J9 [get_ports spw_dout_p[1]]
set_property IOSTANDARD LVDS [get_ports spw_dout_p[1]]
set_property PACKAGE_PIN H9 [get_ports spw_dout_n[1]]
set_property IOSTANDARD LVDS [get_ports spw_dout_n[1]]
set_property PACKAGE_PIN B10 [get_ports spw_sout_p[1]]
set_property IOSTANDARD LVDS [get_ports spw_sout_p[1]]
set_property PACKAGE_PIN A10 [get_ports spw_sout_n[1]]
set_property IOSTANDARD LVDS [get_ports spw_sout_n[1]]
set_property PACKAGE_PIN L8 [get_ports spw_dout_p[2]]
set_property IOSTANDARD LVDS [get_ports spw_dout_p[2]]
set_property PACKAGE_PIN K8 [get_ports spw_dout_n[2]]
set_property IOSTANDARD LVDS [get_ports spw_dout_n[2]]
set_property PACKAGE_PIN D9 [get_ports spw_sout_p[2]]
set_property IOSTANDARD LVDS [get_ports spw_sout_P[2]]
set_property PACKAGE_PIN C9 [get_ports spw_sout_n[2]]
set_property IOSTANDARD LVDS [get_ports spw_sout_n[2]]

# --- Debug Hub ---------------------------------------------
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 3 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]

# --- Misc --------------------------------------------------


# --- Taken from the Xilinx KCU105 User Guide ---------------

# User Clocks
# set_property IOSTANDARD LVDS_25 [get_ports "USER_SI570_CLOCK_N"] */
# set_property PACKAGE_PIN M26 [get_ports "USER_SI570_CLOCK_N"] */
# set_property IOSTANDARD LVDS_25 [get_ports "USER_SI570_CLOCK_P"] */
# set_property PACKAGE_PIN M25 [get_ports "USER_SI570_CLOCK_P"] */
# set_property PACKAGE_PIN G10 [get_ports "CLK_125MHZ_P"] */
# set_property IOSTANDARD  LVDS [get_ports "CLK_125MHZ_P"] */
# set_property PACKAGE_PIN F10 [get_ports "CLK_125MHZ_N"] */
# set_property IOSTANDARD  LVDS [get_ports "CLK_125MHZ_N"] */
# set_property PACKAGE_PIN C23 [get_ports "USER_SMA_CLOCK_N"] */
# set_property IOSTANDARD LVDS [get_ports "USER_SMA_CLOCK_N"] */
# set_property PACKAGE_PIN D23 [get_ports "USER_SMA_CLOCK_P"] */
# set_property IOSTANDARD LVDS [get_ports "USER_SMA_CLOCK_P"] */
# set_property PACKAGE_PIN L22 [get_ports "SI5328_INT_ALM_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SI5328_INT_ALM_LS"] */
# set_property PACKAGE_PIN K23 [get_ports "SI5328_RST_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SI5328_RST_LS"] */
# set_property PACKAGE_PIN AH11 [get_ports "REC_CLOCK_C_N"] */
# set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports "REC_CLOCK_C_N"] */
# set_property PACKAGE_PIN AG11 [get_ports "REC_CLOCK_C_P"] */
# set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports "REC_CLOCK_C_P"] */
# set_property PACKAGE_PIN K20 [get_ports "FPGA_EMCCLK"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "FPGA_EMCCLK"] */

#SI570_CLOCK/SI5328 CLOCK SELECT
# set_property PACKAGE_PIN F12 [get_ports "SI570_CLK_SEL_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SI570_CLK_SEL_LS"] */

#FMC HPC
# set_property DIFF_TERM TRUE [get_ports "FMC_HPC_CLK0_M2C_N"] */
# set_property PACKAGE_PIN G12 [get_ports "FMC_HPC_CLK0_M2C_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_CLK0_M2C_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_CLK0_M2C_P"] */
# set_property DIFF_TERM TRUE [get_ports "FMC_HPC_CLK0_M2C_P"] */
# set_property PACKAGE_PIN H12 [get_ports "FMC_HPC_CLK0_M2C_P"] */
# set_property PACKAGE_PIN D25 [get_ports "FMC_HPC_CLK1_M2C_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_CLK1_M2C_N"] */
# set_property DIFF_TERM TRUE [get_ports "FMC_HPC_CLK1_M2C_N"] */
# set_property PACKAGE_PIN E25 [get_ports "FMC_HPC_CLK1_M2C_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_CLK1_M2C_P"] */
# set_property DIFF_TERM TRUE [get_ports "FMC_HPC_CLK1_M2C_P"] */
# set_property PACKAGE_PIN L27 [get_ports "FMC_HPC_PG_M2C_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "FMC_HPC_PG_M2C_LS"] */
# set_property PACKAGE_PIN H24 [get_ports "FMC_HPC_PRSNT_M2C_B_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "FMC_HPC_PRSNT_M2C_B_LS"] */

#FMC HPC HA
# set_property PACKAGE_PIN G16 [get_ports "FMC_HPC_HA00_CC_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA00_CC_N"] */
# set_property PACKAGE_PIN G17 [get_ports "FMC_HPC_HA00_CC_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA00_CC_P"] */
# set_property PACKAGE_PIN D16 [get_ports "FMC_HPC_HA01_CC_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA01_CC_N"] */
# set_property PACKAGE_PIN E16 [get_ports "FMC_HPC_HA01_CC_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA01_CC_P"] */
# set_property PACKAGE_PIN H18 [get_ports "FMC_HPC_HA02_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA02_N"] */
# set_property PACKAGE_PIN H19 [get_ports "FMC_HPC_HA02_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA02_P"] */
# set_property PACKAGE_PIN G14 [get_ports "FMC_HPC_HA03_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA03_N"] */
# set_property PACKAGE_PIN G15 [get_ports "FMC_HPC_HA03_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA03_P"] */
# set_property PACKAGE_PIN F19 [get_ports "FMC_HPC_HA04_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA04_N"] */
# set_property PACKAGE_PIN G19 [get_ports "FMC_HPC_HA04_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA04_P"] */
# set_property PACKAGE_PIN J14 [get_ports "FMC_HPC_HA05_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA05_N"] */
# set_property PACKAGE_PIN J15 [get_ports "FMC_HPC_HA05_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA05_P"] */
# set_property PACKAGE_PIN K15 [get_ports "FMC_HPC_HA06_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA06_N"] */
# set_property PACKAGE_PIN L15 [get_ports "FMC_HPC_HA06_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA06_P"] */
# set_property PACKAGE_PIN L18 [get_ports "FMC_HPC_HA07_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA07_N"] */
# set_property PACKAGE_PIN L19 [get_ports "FMC_HPC_HA07_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA07_P"] */
# set_property PACKAGE_PIN K17 [get_ports "FMC_HPC_HA08_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA08_N"] */
# set_property PACKAGE_PIN K18 [get_ports "FMC_HPC_HA08_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA08_P"] */
# set_property PACKAGE_PIN F17 [get_ports "FMC_HPC_HA09_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA09_N"] */
# set_property PACKAGE_PIN F18 [get_ports "FMC_HPC_HA09_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA09_P"] */
# set_property PACKAGE_PIN H16 [get_ports "FMC_HPC_HA10_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA10_N"] */
# set_property PACKAGE_PIN H17 [get_ports "FMC_HPC_HA10_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA10_P"] */
# set_property PACKAGE_PIN J18 [get_ports "FMC_HPC_HA11_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA11_N"] */
# set_property PACKAGE_PIN J19 [get_ports "FMC_HPC_HA11_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA11_P"] */
# set_property PACKAGE_PIN J16 [get_ports "FMC_HPC_HA12_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA12_N"] */
# set_property PACKAGE_PIN K16 [get_ports "FMC_HPC_HA12_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA12_P"] */
# set_property PACKAGE_PIN A14 [get_ports "FMC_HPC_HA13_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA13_N"] */
# set_property PACKAGE_PIN B14 [get_ports "FMC_HPC_HA13_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA13_P"] */
# set_property PACKAGE_PIN F14 [get_ports "FMC_HPC_HA14_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA14_N"] */
# set_property PACKAGE_PIN F15 [get_ports "FMC_HPC_HA14_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA14_P"] */
# set_property PACKAGE_PIN C14 [get_ports "FMC_HPC_HA15_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA15_N"] */
# set_property PACKAGE_PIN D14 [get_ports "FMC_HPC_HA15_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA15_P"] */
# set_property PACKAGE_PIN A18 [get_ports "FMC_HPC_HA16_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA16_N"] */
# set_property PACKAGE_PIN A19 [get_ports "FMC_HPC_HA16_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA16_P"] */
# set_property PACKAGE_PIN E17 [get_ports "FMC_HPC_HA17_CC_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA17_CC_N"] */
# set_property PACKAGE_PIN E18 [get_ports "FMC_HPC_HA17_CC_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA17_CC_P"] */
# set_property PACKAGE_PIN B16 [get_ports "FMC_HPC_HA18_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA18_N"] */
# set_property PACKAGE_PIN B17 [get_ports "FMC_HPC_HA18_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA18_P"] */
# set_property PACKAGE_PIN D18 [get_ports "FMC_HPC_HA19_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA19_N"] */
# set_property PACKAGE_PIN D19 [get_ports "FMC_HPC_HA19_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA19_P"] */
# set_property PACKAGE_PIN B19 [get_ports "FMC_HPC_HA20_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA20_N"] */
# set_property PACKAGE_PIN C19 [get_ports "FMC_HPC_HA20_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA20_P"] */
# set_property PACKAGE_PIN D15 [get_ports "FMC_HPC_HA21_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA21_N"] */
# set_property PACKAGE_PIN E15 [get_ports "FMC_HPC_HA21_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA21_P"] */
# set_property PACKAGE_PIN C17 [get_ports "FMC_HPC_HA22_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA22_N"] */
# set_property PACKAGE_PIN C18 [get_ports "FMC_HPC_HA22_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA22_P"] */
# set_property PACKAGE_PIN A15 [get_ports "FMC_HPC_HA23_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA23_N"] */
# set_property PACKAGE_PIN B15 [get_ports "FMC_HPC_HA23_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_HA23_P"] */

#FMC HPC LA
# set_property PACKAGE_PIN G11 [get_ports "FMC_HPC_LA00_CC_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA00_CC_N"] */
# set_property PACKAGE_PIN H11 [get_ports "FMC_HPC_LA00_CC_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA00_CC_P"] */
# set_property PACKAGE_PIN F9 [get_ports "FMC_HPC_LA01_CC_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA01_CC_N"] */
# set_property PACKAGE_PIN G9 [get_ports "FMC_HPC_LA01_CC_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA01_CC_P"] */
# set_property PACKAGE_PIN J10 [get_ports "FMC_HPC_LA02_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA02_N"] */
# set_property PACKAGE_PIN K10 [get_ports "FMC_HPC_LA02_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA02_P"] */
# set_property PACKAGE_PIN A12 [get_ports "FMC_HPC_LA03_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA03_N"] */
# set_property PACKAGE_PIN A13 [get_ports "FMC_HPC_LA03_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA03_P"] */
# set_property PACKAGE_PIN K12 [get_ports "FMC_HPC_LA04_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA04_N"] */
# set_property PACKAGE_PIN L12 [get_ports "FMC_HPC_LA04_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA04_P"] */
# set_property PACKAGE_PIN K13 [get_ports "FMC_HPC_LA05_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA05_N"] */
# set_property PACKAGE_PIN L13 [get_ports "FMC_HPC_LA05_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA05_P"] */
# set_property PACKAGE_PIN C13 [get_ports "FMC_HPC_LA06_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA06_N"] */
# set_property PACKAGE_PIN D13 [get_ports "FMC_HPC_LA06_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA06_P"] */
# set_property PACKAGE_PIN E8 [get_ports "FMC_HPC_LA07_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA07_N"] */
# set_property PACKAGE_PIN F8 [get_ports "FMC_HPC_LA07_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA07_P"] */
# set_property PACKAGE_PIN H8 [get_ports "FMC_HPC_LA08_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA08_N"] */
# set_property PACKAGE_PIN J8 [get_ports "FMC_HPC_LA08_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA08_P"] */
# set_property PACKAGE_PIN H9 [get_ports "FMC_HPC_LA09_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA09_N"] */
# set_property PACKAGE_PIN J9 [get_ports "FMC_HPC_LA09_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA09_P"] */
# set_property PACKAGE_PIN K8 [get_ports "FMC_HPC_LA10_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA10_N"] */
# set_property PACKAGE_PIN L8 [get_ports "FMC_HPC_LA10_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA10_P"] */
# set_property PACKAGE_PIN J11 [get_ports "FMC_HPC_LA11_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA11_N"] */
# set_property PACKAGE_PIN K11 [get_ports "FMC_HPC_LA11_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA11_P"] */
# set_property PACKAGE_PIN D10 [get_ports "FMC_HPC_LA12_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA12_N"] */
# set_property PACKAGE_PIN E10 [get_ports "FMC_HPC_LA12_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA12_P"] */
# set_property PACKAGE_PIN C9 [get_ports "FMC_HPC_LA13_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA13_N"] */
# set_property PACKAGE_PIN D9 [get_ports "FMC_HPC_LA13_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA13_P"] */
# set_property PACKAGE_PIN A10 [get_ports "FMC_HPC_LA14_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA14_N"] */
# set_property PACKAGE_PIN B10 [get_ports "FMC_HPC_LA14_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA14_P"] */
# set_property PACKAGE_PIN C8 [get_ports "FMC_HPC_LA15_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA15_N"] */
# set_property PACKAGE_PIN D8 [get_ports "FMC_HPC_LA15_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA15_P"] */
# set_property PACKAGE_PIN A9 [get_ports "FMC_HPC_LA16_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA16_N"] */
# set_property PACKAGE_PIN B9 [get_ports "FMC_HPC_LA16_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA16_P"] */
# set_property PACKAGE_PIN C24 [get_ports "FMC_HPC_LA17_CC_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA17_CC_N"] */
# set_property PACKAGE_PIN D24 [get_ports "FMC_HPC_LA17_CC_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA17_CC_P"] */
# set_property PACKAGE_PIN E23 [get_ports "FMC_HPC_LA18_CC_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA18_CC_N"] */
# set_property PACKAGE_PIN E22 [get_ports "FMC_HPC_LA18_CC_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA18_CC_P"] */
# set_property PACKAGE_PIN C22 [get_ports "FMC_HPC_LA19_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA19_N"] */
# set_property PACKAGE_PIN C21 [get_ports "FMC_HPC_LA19_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA19_P"] */
# set_property PACKAGE_PIN A24 [get_ports "FMC_HPC_LA20_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA20_N"] */
# set_property PACKAGE_PIN B24 [get_ports "FMC_HPC_LA20_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA20_P"] */
# set_property PACKAGE_PIN F24 [get_ports "FMC_HPC_LA21_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA21_N"] */
# set_property PACKAGE_PIN F23 [get_ports "FMC_HPC_LA21_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA21_P"] */
# set_property PACKAGE_PIN F25 [get_ports "FMC_HPC_LA22_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA22_N"] */
# set_property PACKAGE_PIN G24 [get_ports "FMC_HPC_LA22_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA22_P"] */
# set_property PACKAGE_PIN F22 [get_ports "FMC_HPC_LA23_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA23_N"] */
# set_property PACKAGE_PIN G22 [get_ports "FMC_HPC_LA23_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA23_P"] */
# set_property PACKAGE_PIN E21 [get_ports "FMC_HPC_LA24_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA24_N"] */
# set_property PACKAGE_PIN E20 [get_ports "FMC_HPC_LA24_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA24_P"] */
# set_property PACKAGE_PIN D21 [get_ports "FMC_HPC_LA25_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA25_N"] */
# set_property PACKAGE_PIN D20 [get_ports "FMC_HPC_LA25_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA25_P"] */
# set_property PACKAGE_PIN F20 [get_ports "FMC_HPC_LA26_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA26_N"] */
# set_property PACKAGE_PIN G20 [get_ports "FMC_HPC_LA26_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA26_P"] */
# set_property PACKAGE_PIN G21 [get_ports "FMC_HPC_LA27_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA27_N"] */
# set_property PACKAGE_PIN H21 [get_ports "FMC_HPC_LA27_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA27_P"] */
# set_property PACKAGE_PIN B22 [get_ports "FMC_HPC_LA28_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA28_N"] */
# set_property PACKAGE_PIN B21 [get_ports "FMC_HPC_LA28_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA28_P"] */
# set_property PACKAGE_PIN A20 [get_ports "FMC_HPC_LA29_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA29_N"] */
# set_property PACKAGE_PIN B20 [get_ports "FMC_HPC_LA29_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA29_P"] */
# set_property PACKAGE_PIN B26 [get_ports "FMC_HPC_LA30_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA30_N"] */
# set_property PACKAGE_PIN C26 [get_ports "FMC_HPC_LA30_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA30_P"] */
# set_property PACKAGE_PIN A25 [get_ports "FMC_HPC_LA31_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA31_N"] */
# set_property PACKAGE_PIN B25 [get_ports "FMC_HPC_LA31_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA31_P"] */
# set_property PACKAGE_PIN D26 [get_ports "FMC_HPC_LA32_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA32_N"] */
# set_property PACKAGE_PIN E26 [get_ports "FMC_HPC_LA32_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA32_P"] */
# set_property PACKAGE_PIN A28 [get_ports "FMC_HPC_LA33_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA33_N"] */
# set_property PACKAGE_PIN A27 [get_ports "FMC_HPC_LA33_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_HPC_LA33_P"] */

#FMC LPC
# set_property PACKAGE_PIN AA25 [get_ports "FMC_LPC_CLK0_M2C_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_CLK0_M2C_N"] */
# set_property DIFF_TERM TRUE [get_ports "FMC_LPC_CLK0_M2C_N"] */
# set_property PACKAGE_PIN AA24 [get_ports "FMC_LPC_CLK0_M2C_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_CLK0_M2C_P"] */
# set_property DIFF_TERM TRUE [get_ports "FMC_LPC_CLK0_M2C_P"] */
# set_property PACKAGE_PIN AC32 [get_ports "FMC_LPC_CLK1_M2C_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_CLK1_M2C_N"] */
# set_property DIFF_TERM TRUE [get_ports "FMC_LPC_CLK1_M2C_N"] */
# set_property PACKAGE_PIN AC31 [get_ports "FMC_LPC_CLK1_M2C_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_CLK1_M2C_P"] */
# set_property DIFF_TERM TRUE [get_ports "FMC_LPC_CLK1_M2C_P"] */
# set_property PACKAGE_PIN J26 [get_ports "FMC_LPC_PRSNT_M2C_B_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "FMC_LPC_PRSNT_M2C_B_LS"] */
# set_property PACKAGE_PIN L24 [get_ports "FMC_VADJ_ON_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "FMC_VADJ_ON_LS"] */

#FMC LPC LA
# set_property PACKAGE_PIN W24 [get_ports "FMC_LPC_LA00_CC_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA00_CC_N"] */
# set_property PACKAGE_PIN W23 [get_ports "FMC_LPC_LA00_CC_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA00_CC_P"] */
# set_property PACKAGE_PIN Y25 [get_ports "FMC_LPC_LA01_CC_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA01_CC_N"] */
# set_property PACKAGE_PIN W25 [get_ports "FMC_LPC_LA01_CC_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA01_CC_P"] */
# set_property PACKAGE_PIN AB22 [get_ports "FMC_LPC_LA02_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA02_N"] */
# set_property PACKAGE_PIN AA22 [get_ports "FMC_LPC_LA02_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA02_P"] */
# set_property PACKAGE_PIN Y28 [get_ports "FMC_LPC_LA03_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA03_N"] */
# set_property PACKAGE_PIN W28 [get_ports "FMC_LPC_LA03_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA03_P"] */
# set_property PACKAGE_PIN U27 [get_ports "FMC_LPC_LA04_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA04_N"] */
# set_property PACKAGE_PIN U26 [get_ports "FMC_LPC_LA04_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA04_P"] */
# set_property PACKAGE_PIN V28 [get_ports "FMC_LPC_LA05_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA05_N"] */
# set_property PACKAGE_PIN V27 [get_ports "FMC_LPC_LA05_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA05_P"] */
# set_property PACKAGE_PIN W29 [get_ports "FMC_LPC_LA06_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA06_N"] */
# set_property PACKAGE_PIN V29 [get_ports "FMC_LPC_LA06_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA06_P"] */
# set_property PACKAGE_PIN V23 [get_ports "FMC_LPC_LA07_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA07_N"] */
# set_property PACKAGE_PIN V22 [get_ports "FMC_LPC_LA07_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA07_P"] */
# set_property PACKAGE_PIN U25 [get_ports "FMC_LPC_LA08_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA08_N"] */
# set_property PACKAGE_PIN U24 [get_ports "FMC_LPC_LA08_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA08_P"] */
# set_property PACKAGE_PIN W26 [get_ports "FMC_LPC_LA09_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA09_N"] */
# set_property PACKAGE_PIN V26 [get_ports "FMC_LPC_LA09_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA09_P"] */
# set_property PACKAGE_PIN T23 [get_ports "FMC_LPC_LA10_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA10_N"] */
# set_property PACKAGE_PIN T22 [get_ports "FMC_LPC_LA10_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA10_P"] */
# set_property PACKAGE_PIN W21 [get_ports "FMC_LPC_LA11_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA11_N"] */
# set_property PACKAGE_PIN V21 [get_ports "FMC_LPC_LA11_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA11_P"] */
# set_property PACKAGE_PIN AC23 [get_ports "FMC_LPC_LA12_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA12_N"] */
# set_property PACKAGE_PIN AC22 [get_ports "FMC_LPC_LA12_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA12_P"] */
# set_property PACKAGE_PIN AB20 [get_ports "FMC_LPC_LA13_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA13_N"] */
# set_property PACKAGE_PIN AA20 [get_ports "FMC_LPC_LA13_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA13_P"] */
# set_property PACKAGE_PIN U22 [get_ports "FMC_LPC_LA14_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA14_N"] */
# set_property PACKAGE_PIN U21 [get_ports "FMC_LPC_LA14_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA14_P"] */
# set_property PACKAGE_PIN AB26 [get_ports "FMC_LPC_LA15_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA15_N"] */
# set_property PACKAGE_PIN AB25 [get_ports "FMC_LPC_LA15_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA15_P"] */
# set_property PACKAGE_PIN AC21 [get_ports "FMC_LPC_LA16_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA16_N"] */
# set_property PACKAGE_PIN AB21 [get_ports "FMC_LPC_LA16_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA16_P"] */
# set_property PACKAGE_PIN AB32 [get_ports "FMC_LPC_LA17_CC_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA17_CC_N"] */
# set_property PACKAGE_PIN AA32 [get_ports "FMC_LPC_LA17_CC_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA17_CC_P"] */
# set_property PACKAGE_PIN AB31 [get_ports "FMC_LPC_LA18_CC_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA18_CC_N"] */
# set_property PACKAGE_PIN AB30 [get_ports "FMC_LPC_LA18_CC_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA18_CC_P"] */
# set_property PACKAGE_PIN AB29 [get_ports "FMC_LPC_LA19_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA19_N"] */
# set_property PACKAGE_PIN AA29 [get_ports "FMC_LPC_LA19_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA19_P"] */
# set_property PACKAGE_PIN AB34 [get_ports "FMC_LPC_LA20_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA20_N"] */
# set_property PACKAGE_PIN AA34 [get_ports "FMC_LPC_LA20_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA20_P"] */
# set_property PACKAGE_PIN AD33 [get_ports "FMC_LPC_LA21_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA21_N"] */
# set_property PACKAGE_PIN AC33 [get_ports "FMC_LPC_LA21_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA21_P"] */
# set_property PACKAGE_PIN AD34 [get_ports "FMC_LPC_LA22_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA22_N"] */
# set_property PACKAGE_PIN AC34 [get_ports "FMC_LPC_LA22_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA22_P"] */
# set_property PACKAGE_PIN AD31 [get_ports "FMC_LPC_LA23_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA23_N"] */
# set_property PACKAGE_PIN AD30 [get_ports "FMC_LPC_LA23_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA23_P"] */
# set_property PACKAGE_PIN AF32 [get_ports "FMC_LPC_LA24_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA24_N"] */
# set_property PACKAGE_PIN AE32 [get_ports "FMC_LPC_LA24_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA24_P"] */
# set_property PACKAGE_PIN AF34 [get_ports "FMC_LPC_LA25_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA25_N"] */
# set_property PACKAGE_PIN AE33 [get_ports "FMC_LPC_LA25_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA25_P"] */
# set_property PACKAGE_PIN AG34 [get_ports "FMC_LPC_LA26_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA26_N"] */
# set_property PACKAGE_PIN AF33 [get_ports "FMC_LPC_LA26_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA26_P"] */
# set_property PACKAGE_PIN AG32 [get_ports "FMC_LPC_LA27_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA27_N"] */
# set_property PACKAGE_PIN AG31 [get_ports "FMC_LPC_LA27_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA27_P"] */
# set_property PACKAGE_PIN W31 [get_ports "FMC_LPC_LA28_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA28_N"] */
# set_property PACKAGE_PIN V31 [get_ports "FMC_LPC_LA28_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA28_P"] */
# set_property PACKAGE_PIN V34 [get_ports "FMC_LPC_LA29_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA29_N"] */
# set_property PACKAGE_PIN U34 [get_ports "FMC_LPC_LA29_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA29_P"] */
# set_property PACKAGE_PIN Y32 [get_ports "FMC_LPC_LA30_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA30_N"] */
# set_property PACKAGE_PIN Y31 [get_ports "FMC_LPC_LA30_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA30_P"] */
# set_property PACKAGE_PIN W34 [get_ports "FMC_LPC_LA31_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA31_N"] */
# set_property PACKAGE_PIN V33 [get_ports "FMC_LPC_LA31_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA31_P"] */
# set_property PACKAGE_PIN Y30 [get_ports "FMC_LPC_LA32_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA32_N"] */
# set_property PACKAGE_PIN W30 [get_ports "FMC_LPC_LA32_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA32_P"] */
# set_property PACKAGE_PIN Y33 [get_ports "FMC_LPC_LA33_N"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA33_N"] */
# set_property PACKAGE_PIN W33 [get_ports "FMC_LPC_LA33_P"] */
# set_property IOSTANDARD LVDS [get_ports "FMC_LPC_LA33_P"] */

#GPIO ROTARY SW
# set_property PACKAGE_PIN Y21 [get_ports "ROTARY_INCA"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "ROTARY_INCA"] */
# set_property PACKAGE_PIN AD26 [get_ports "ROTARY_INCB"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "ROTARY_INCB"] */
# set_property PACKAGE_PIN AF28 [get_ports "ROTARY_PUSH"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "ROTARY_PUSH"] */

#GPIO SMA
# set_property PACKAGE_PIN G27 [get_ports "USER_SMA_GPIO_N"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "USER_SMA_GPIO_N"] */
# set_property PACKAGE_PIN H27 [get_ports "USER_SMA_GPIO_P"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "USER_SMA_GPIO_P"] */

#HDMI
# set_property PACKAGE_PIN AJ13 [get_ports "HDMI_INT"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_INT"] */
# set_property PACKAGE_PIN AF13 [get_ports "HDMI_R_CLK"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_CLK"] */
# set_property PACKAGE_PIN AK11 [get_ports "HDMI_R_D0"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D0"] */
# set_property PACKAGE_PIN AP11 [get_ports "HDMI_R_D1"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D1"] */
# set_property PACKAGE_PIN AP13 [get_ports "HDMI_R_D2"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D2"] */
# set_property PACKAGE_PIN AN13 [get_ports "HDMI_R_D3"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D3"] */
# set_property PACKAGE_PIN AN11 [get_ports "HDMI_R_D4"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D4"] */
# set_property PACKAGE_PIN AM11 [get_ports "HDMI_R_D5"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D5"] */
# set_property PACKAGE_PIN AN12 [get_ports "HDMI_R_D6"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D6"] */
# set_property PACKAGE_PIN AM12 [get_ports "HDMI_R_D7"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D7"] */
# set_property PACKAGE_PIN AL12 [get_ports "HDMI_R_D8"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D8"] */
# set_property PACKAGE_PIN AK12 [get_ports "HDMI_R_D9"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D9"] */
# set_property PACKAGE_PIN AL13 [get_ports "HDMI_R_D10"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D10"] */
# set_property PACKAGE_PIN AK13 [get_ports "HDMI_R_D11"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D11"] */
# set_property PACKAGE_PIN AD11 [get_ports "HDMI_R_D12"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D12"] */
# set_property PACKAGE_PIN AH12 [get_ports "HDMI_R_D13"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D13"] */
# set_property PACKAGE_PIN AG12 [get_ports "HDMI_R_D14"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D14"] */
# set_property PACKAGE_PIN AJ11 [get_ports "HDMI_R_D15"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D15"] */
# set_property PACKAGE_PIN AG10 [get_ports "HDMI_R_D16"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D16"] */
# set_property PACKAGE_PIN AK8 [get_ports "HDMI_R_D17"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_D17"] */
# set_property PACKAGE_PIN AE11 [get_ports "HDMI_R_DE"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_DE"] */
# set_property PACKAGE_PIN AE13 [get_ports "HDMI_R_HSYNC"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_HSYNC"] */
# set_property PACKAGE_PIN AE12 [get_ports "HDMI_R_SPDIF"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_SPDIF"] */
# set_property PACKAGE_PIN AH13 [get_ports "HDMI_R_VSYNC"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_R_VSYNC"] */
# set_property PACKAGE_PIN AF12 [get_ports "HDMI_SPDIF_OUT_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "HDMI_SPDIF_OUT_LS"] */

#PCIE
# set_property PACKAGE_PIN K22 [get_ports "PCIE_PERST_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "PCIE_PERST_LS"] */
# set_property PACKAGE_PIN N23 [get_ports "PCIE_WAKE_B_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "PCIE_WAKE_B_LS"] */

#QSPI
# set_property PACKAGE_PIN G26 [get_ports "QSPI1_CS_B"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "QSPI1_CS_B"] */
# set_property PACKAGE_PIN M20 [get_ports "QSPI1_IO0"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "QSPI1_IO0"] */
# set_property PACKAGE_PIN L20 [get_ports "QSPI1_IO1"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "QSPI1_IO1"] */
# set_property PACKAGE_PIN R21 [get_ports "QSPI1_IO2"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "QSPI1_IO2"] */
# set_property PACKAGE_PIN R22 [get_ports "QSPI1_IO3"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "QSPI1_IO3"] */

#SDIO
# set_property PACKAGE_PIN AM10 [get_ports "SDIO_CD_FPGA"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SDIO_CD_FPGA"] */
# set_property PACKAGE_PIN AL10 [get_ports "SDIO_CLK_FPGA"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SDIO_CLK_FPGA"] */
# set_property PACKAGE_PIN AD9 [get_ports "SDIO_CMD_FPGA"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SDIO_CMD_FPGA"] */
# set_property PACKAGE_PIN AP9 [get_ports "SDIO_DATA0_FPGA"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SDIO_DATA0_FPGA"] */
# set_property PACKAGE_PIN AN9 [get_ports "SDIO_DATA1_FPGA"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SDIO_DATA1_FPGA"] */
# set_property PACKAGE_PIN AH9 [get_ports "SDIO_DATA2_FPGA"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SDIO_DATA2_FPGA"] */
# set_property PACKAGE_PIN AH8 [get_ports "SDIO_DATA3_FPGA"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SDIO_DATA3_FPGA"] */

#SFP
# set_property PACKAGE_PIN K21 [get_ports "SFP0_LOS_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SFP0_LOS_LS"] */
# set_property PACKAGE_PIN AL8 [get_ports "SFP0_TX_DISABLE"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SFP0_TX_DISABLE"] */
# set_property PACKAGE_PIN AM9 [get_ports "SFP1_LOS_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SFP1_LOS_LS"] */
# set_property PACKAGE_PIN D28 [get_ports "SFP1_TX_DISABLE"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SFP1_TX_DISABLE"] */

#SYSTEM CONTROLLER
# set_property PACKAGE_PIN AJ10 [get_ports "SYSCTLR_GPIO_5"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SYSCTLR_GPIO_5"] */
# set_property PACKAGE_PIN AG9 [get_ports "SYSCTLR_GPIO_6"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SYSCTLR_GPIO_6"] */
# set_property PACKAGE_PIN AF10 [get_ports "SYSCTLR_GPIO_7"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SYSCTLR_GPIO_7"] */

#SYSMON
# set_property PACKAGE_PIN E13 [get_ports "SYSMON_AD0_R_N"] */
# set_property IOSTANDARD ANALOG [get_ports "SYSMON_AD0_R_N"] */
# set_property PACKAGE_PIN F13 [get_ports "SYSMON_AD0_R_P"] */
# set_property IOSTANDARD ANALOG [get_ports "SYSMON_AD0_R_P"] */
# set_property PACKAGE_PIN H13 [get_ports "SYSMON_AD2_R_N"] */
# set_property IOSTANDARD ANALOG [get_ports "SYSMON_AD2_R_N"] */
# set_property PACKAGE_PIN J13 [get_ports "SYSMON_AD2_R_P"] */
# set_property IOSTANDARD ANALOG [get_ports "SYSMON_AD2_R_P"] */
# set_property PACKAGE_PIN B11 [get_ports "SYSMON_AD8_R_N"] */
# set_property IOSTANDARD ANALOG [get_ports "SYSMON_AD8_R_N"] */
# set_property PACKAGE_PIN C11 [get_ports "SYSMON_AD8_R_P"] */
# set_property IOSTANDARD ANALOG [get_ports "SYSMON_AD8_R_P"] */
# set_property PACKAGE_PIN T27 [get_ports "SYSMON_MUX_ADDR0_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SYSMON_MUX_ADDR0_LS"] */
# set_property PACKAGE_PIN R27 [get_ports "SYSMON_MUX_ADDR1_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SYSMON_MUX_ADDR1_LS"] */
# set_property PACKAGE_PIN N27 [get_ports "SYSMON_MUX_ADDR2_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SYSMON_MUX_ADDR2_LS"] */
# set_property PACKAGE_PIN N21 [get_ports "SYSMON_SCL_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SYSMON_SCL_LS"] */
# set_property PACKAGE_PIN M21 [get_ports "SYSMON_SDA_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SYSMON_SDA_LS"] */

#FAN
# set_property PACKAGE_PIN AJ9 [get_ports "SM_FAN_PWM"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SM_FAN_PWM"] */
# set_property PACKAGE_PIN AJ8 [get_ports "SM_FAN_TACH"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "SM_FAN_TACH"] */

#MAXIM CABLE
# set_property PACKAGE_PIN AL9 [get_ports "MAXIM_CABLE_B_FPGA"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "MAXIM_CABLE_B_FPGA"] */

#PMBUS
# set_property PACKAGE_PIN AK10 [get_ports "PMBUS_ALERT_FPGA"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "PMBUS_ALERT_FPGA"] */

#VADJ PGOOD
# set_property PACKAGE_PIN M27 [get_ports "VADJ_1V8_PGOOD_LS"] */
# set_property IOSTANDARD LVCMOS18 [get_ports "VADJ_1V8_PGOOD_LS"] */

set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 40 [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]

set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
