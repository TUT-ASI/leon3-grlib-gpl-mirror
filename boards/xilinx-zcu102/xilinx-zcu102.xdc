#-----------------------------------------------------------
#                  Constraints                             -
#-----------------------------------------------------------

# --- Define and constrain system clock 3.332
create_clock -period 3.332 -name clk300 [get_ports clk300p]
set_propagated_clock [get_clocks clk300]

# --- False paths
set_false_path -to [get_ports led*]
set_false_path -from [get_ports reset]
set_false_path -from [get_ports button*]
set_false_path -from [get_ports switch*]

# --- Clock Domain Crossing (in case of the DDR4 MIG)
set_false_path -from [get_clocks mmcm_clkout0] -to [get_clocks -include_generated_clocks mmcm_clkout1]
set_false_path -from [get_clocks mmcm_clkout1] -to [get_clocks -include_generated_clocks mmcm_clkout0]


#-----------------------------------------------------------
#                  Pin and IO Property                     -
#-----------------------------------------------------------

# --- Clocks -----------------------------------------------
set_property PACKAGE_PIN AL7      [get_ports clk300n]
set_property IOSTANDARD  DIFF_SSTL12  [get_ports clk300n]
set_property PACKAGE_PIN AL8      [get_ports clk300p]
set_property IOSTANDARD  DIFF_SSTL12  [get_ports clk300p]


# --- Reset ------------------------------------------------
set_property PACKAGE_PIN AM13     [get_ports reset]
set_property IOSTANDARD  LVCMOS33 [get_ports reset]

# --- Switches ---------------------------------------------
set_property PACKAGE_PIN AN14     [get_ports {switch[0]}]
set_property PACKAGE_PIN AP14     [get_ports {switch[1]}]
set_property PACKAGE_PIN AM14     [get_ports {switch[2]}]
set_property PACKAGE_PIN AN13     [get_ports {switch[3]}]
set_property PACKAGE_PIN AN12     [get_ports {switch[4]}]
set_property PACKAGE_PIN AP12     [get_ports {switch[5]}]
set_property PACKAGE_PIN AL13     [get_ports {switch[6]}]

set_property IOSTANDARD  LVCMOS33 [get_ports switch*]



# --- LEDs -------------------------------------------------
set_property PACKAGE_PIN AG14     [get_ports {led[0]}]
set_property PACKAGE_PIN AF13     [get_ports {led[1]}]
set_property PACKAGE_PIN AE13     [get_ports {led[2]}]
set_property PACKAGE_PIN AJ14     [get_ports {led[3]}]
set_property PACKAGE_PIN AJ15     [get_ports {led[4]}]
set_property PACKAGE_PIN AH13     [get_ports {led[5]}]
set_property PACKAGE_PIN AH14     [get_ports {led[6]}]
set_property PACKAGE_PIN AL12     [get_ports {led[7]}]

set_property IOSTANDARD  LVCMOS33 [get_ports led*]


# --- Push Buttons -----------------------------------------
set_property PACKAGE_PIN AG13 [get_ports {button[0]}]
set_property PACKAGE_PIN AE14 [get_ports {button[1]}]
set_property PACKAGE_PIN AG15 [get_ports {button[2]}]
set_property PACKAGE_PIN AE15 [get_ports {button[3]}]
set_property PACKAGE_PIN AF15 [get_ports {button[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports button*]

# --- GPIO PMOD0 -------------------------------------------
set_property PACKAGE_PIN A20 [get_ports {gpio[0]}]
set_property PACKAGE_PIN B20 [get_ports {gpio[1]}]
set_property PACKAGE_PIN A22 [get_ports {gpio[2]}]
set_property PACKAGE_PIN A21 [get_ports {gpio[3]}]
set_property PACKAGE_PIN B21 [get_ports {gpio[4]}]
set_property PACKAGE_PIN C21 [get_ports {gpio[5]}]
set_property PACKAGE_PIN C22 [get_ports {gpio[6]}]
set_property PACKAGE_PIN D21 [get_ports {gpio[7]}]

set_property UNAVAILABLE_DURING_CALIBRATION true [get_ports {gpio[2]}]
set_property UNAVAILABLE_DURING_CALIBRATION true [get_ports {gpio[8]}]


# --- GPIO PMOD1 -------------------------------------------
set_property PACKAGE_PIN D20 [get_ports {gpio[8]}]
set_property PACKAGE_PIN E20 [get_ports {gpio[9]}]
set_property PACKAGE_PIN D22 [get_ports {gpio[10]}]
set_property PACKAGE_PIN E22 [get_ports {gpio[11]}]
set_property PACKAGE_PIN F20 [get_ports {gpio[12]}]
set_property PACKAGE_PIN G20 [get_ports {gpio[13]}]
set_property PACKAGE_PIN J20 [get_ports {gpio[14]}]
set_property PACKAGE_PIN J19 [get_ports {gpio[15]}]

set_property IOSTANDARD LVCMOS33 [get_ports gpio*]



# --- USB UART ---------------------------------------------
set_property PACKAGE_PIN E12 [get_ports dsuctsn]
set_property PACKAGE_PIN D12 [get_ports dsurtsn]
set_property PACKAGE_PIN E13 [get_ports dsurx]
set_property PACKAGE_PIN F13 [get_ports dsutx]

set_property IOSTANDARD LVCMOS33 [get_ports dsu*]



# --- Debug Hub ---------------------------------------------
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 3 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk300]




# Without MIG
#set_max_delay -from [get_clocks clk_nobuf] -to   [get_clocks clk125*] 12.000
#set_max_delay -to   [get_clocks clk_nobuf] -from [get_clocks clk125*] 12.000

# With MIG
#set_max_delay -from [get_clocks mmcm_clkout*] -to   [get_clocks clk125*] 12.000
#set_max_delay -to   [get_clocks mmcm_clkout*] -from [get_clocks clk125*] 12.000


# --- DDR4 (MIG) --------------------------------------------

set_property PACKAGE_PIN AM8 [get_ports ddr4_addr[0]]
set_property PACKAGE_PIN AM9 [get_ports ddr4_addr[1]]
set_property PACKAGE_PIN AP8 [get_ports ddr4_addr[2]]
set_property PACKAGE_PIN AN8 [get_ports ddr4_addr[3]]
set_property PACKAGE_PIN AK10 [get_ports ddr4_addr[4]]
set_property PACKAGE_PIN AJ10 [get_ports ddr4_addr[5]]
set_property PACKAGE_PIN AP9 [get_ports ddr4_addr[6]]
set_property PACKAGE_PIN AN9 [get_ports ddr4_addr[7]]
set_property PACKAGE_PIN AP10 [get_ports ddr4_addr[8]]
set_property PACKAGE_PIN AP11 [get_ports ddr4_addr[9]]
set_property PACKAGE_PIN AM10 [get_ports ddr4_addr[10]]
set_property PACKAGE_PIN AL10 [get_ports ddr4_addr[11]]
set_property PACKAGE_PIN AM11 [get_ports ddr4_addr[12]]
set_property PACKAGE_PIN AL11 [get_ports ddr4_addr[13]]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_addr*]

set_property PACKAGE_PIN AK12 [get_ports ddr4_ba[0]]
set_property PACKAGE_PIN AJ12 [get_ports ddr4_ba[1]]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_ba*]
set_property PACKAGE_PIN AK7 [get_ports ddr4_bg[0]]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_bg*]

set_property PACKAGE_PIN AJ7 [get_ports ddr4_we_n]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_we_n]
set_property PACKAGE_PIN AJ9 [get_ports ddr4_ras_n]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_ras_n]
set_property PACKAGE_PIN AL5 [get_ports ddr4_cas_n]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_cas_n]

set_property PACKAGE_PIN AN7 [get_ports ddr4_ck_t[0]]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports ddr4_ck_t[0]]
set_property PACKAGE_PIN AP7 [get_ports ddr4_ck_c[0]]
set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports ddr4_ck_c[0]]

set_property PACKAGE_PIN AM3 [get_ports ddr4_cke[0]]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_cke[0]]
set_property PACKAGE_PIN AK8 [get_ports ddr4_act_n]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_act_n]
set_property PACKAGE_PIN AP1 [get_ports ddr4_par]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_par]

set_property PACKAGE_PIN AH9 [get_ports ddr4_reset_n]
set_property IOSTANDARD LVCMOS18 [get_ports ddr4_reset_n]

set_property PACKAGE_PIN AK9 [get_ports ddr4_odt[0]]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_odt[0]]
set_property PACKAGE_PIN AP2 [get_ports ddr4_cs_n[0]]
set_property IOSTANDARD SSTL12_DCI [get_ports ddr4_cs_n[0]]

set_property PACKAGE_PIN AK4 [get_ports ddr4_dq[0]]
set_property PACKAGE_PIN AK5 [get_ports ddr4_dq[1]]
set_property PACKAGE_PIN AN4 [get_ports ddr4_dq[2]]
set_property PACKAGE_PIN AM4 [get_ports ddr4_dq[3]]
set_property PACKAGE_PIN AP4 [get_ports ddr4_dq[4]]
set_property PACKAGE_PIN AP5 [get_ports ddr4_dq[5]]
set_property PACKAGE_PIN AM5 [get_ports ddr4_dq[6]]
set_property PACKAGE_PIN AM6 [get_ports ddr4_dq[7]]
set_property PACKAGE_PIN AK2 [get_ports ddr4_dq[8]]
set_property PACKAGE_PIN AK3 [get_ports ddr4_dq[9]]
set_property PACKAGE_PIN AL1 [get_ports ddr4_dq[10]]
set_property PACKAGE_PIN AK1 [get_ports ddr4_dq[11]]
set_property PACKAGE_PIN AN1 [get_ports ddr4_dq[12]]
set_property PACKAGE_PIN AM1 [get_ports ddr4_dq[13]]
set_property PACKAGE_PIN AP3 [get_ports ddr4_dq[14]]
set_property PACKAGE_PIN AN3 [get_ports ddr4_dq[15]]
set_property IOSTANDARD POD12_DCI [get_ports ddr4_dq*]

set_property PACKAGE_PIN AN6 [get_ports ddr4_dqs_t[0]]
set_property IOSTANDARD DIFF_POD12_DCI [get_ports ddr4_dqs_t[0]]
set_property PACKAGE_PIN AP6 [get_ports ddr4_dqs_c[0]]
set_property IOSTANDARD DIFF_POD12_DCI [get_ports ddr4_dqs_c[0]]
set_property PACKAGE_PIN AL3 [get_ports ddr4_dqs_t[1]]
set_property IOSTANDARD DIFF_POD12_DCI [get_ports ddr4_dqs_t[1]]
set_property PACKAGE_PIN AL2 [get_ports ddr4_dqs_c[1]]
set_property IOSTANDARD DIFF_POD12_DCI [get_ports ddr4_dqs_c[1]]

set_property PACKAGE_PIN AL6 [get_ports ddr4_dm_n[0]]
set_property PACKAGE_PIN AN2 [get_ports ddr4_dm_n[1]]
set_property IOSTANDARD POD12_DCI [get_ports ddr4_dm_n*]


# --- Misc --------------------------------------------------

#set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
#set_property BITSTREAM.CONFIG.CONFIGRATE 40 [current_design]
#set_property CONFIG_VOLTAGE 1.8 [current_design]
#set_property CFGBVS GND [current_design]

#set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
#set_property CONFIG_MODE SPIx4 [current_design]

