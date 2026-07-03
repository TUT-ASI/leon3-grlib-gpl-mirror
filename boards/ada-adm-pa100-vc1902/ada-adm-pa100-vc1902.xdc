#-----------------------------------------------------------
#                  Constraints                             -
#-----------------------------------------------------------

###Constraints should be competely updated these are only placeholders

# --- Define and constrain system clock

create_clock -period 3.333 -name clk300 [get_ports clk300p]
set_propagated_clock [get_clocks clk300]

set_property PACKAGE_PIN AR2 [get_ports clk300p]
set_property IOSTANDARD LVDS15 [get_ports clk300p]
#set_property DIFF_TERM_ADV TERM_100 [get_ports clk300p]

set_property PACKAGE_PIN AR1 [get_ports clk300n]
set_property IOSTANDARD LVDS15 [get_ports clk300n]
#set_property DIFF_TERM_ADV TERM_100 [get_ports clk300n]

# set_max_delay -from [get_ports {clk300?}]  100.0
# set_min_delay -from [get_ports {clk300?}] -100.0


# --- Reset ------------------------------------------------

set_property PACKAGE_PIN AW2 [get_ports reset]
set_property IOSTANDARD LVCMOS15 [get_ports reset]


# --- LEDs -------------------------------------------------

set_property PACKAGE_PIN M20 [get_ports {led[0]}]
set_property PACKAGE_PIN M21 [get_ports {led[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports led*]

set_max_delay -to [get_ports led*] 100.000
set_min_delay -to [get_ports led*] -100.000


# --- USB UART ---------------------------------------------

set_property PACKAGE_PIN K17 [get_ports dsurx]
set_property PACKAGE_PIN L18 [get_ports dsutx]

set_property IOSTANDARD LVCMOS33 [get_ports dsu*]

set_max_delay -to [get_ports dsutx] 100.000
set_min_delay -to [get_ports dsutx] -100.000


# --- FMC (SpaceWire) ---------------------------------------

# set_property PACKAGE_PIN AP19 [ get_ports spw_din_p[1] ]
# set_property PACKAGE_PIN AP18 [ get_ports spw_din_n[1] ]

# set_property PACKAGE_PIN BE17 [ get_ports spw_sin_p[1] ]
# set_property PACKAGE_PIN BD17 [ get_ports spw_sin_n[1] ]

# set_property PACKAGE_PIN AW19 [ get_ports spw_din_p[2] ]
# set_property PACKAGE_PIN AY18 [ get_ports spw_din_n[2] ]

# set_property PACKAGE_PIN BB16 [ get_ports spw_sin_p[2] ]
# set_property PACKAGE_PIN BC16 [ get_ports spw_sin_n[2] ]

# set_property PACKAGE_PIN AM18 [ get_ports spw_dout_p[1] ]
# set_property PACKAGE_PIN AN17 [ get_ports spw_dout_n[1] ]

# set_property PACKAGE_PIN AU17 [ get_ports spw_sout_p[1] ]
# set_property PACKAGE_PIN AV17 [ get_ports spw_sout_n[1] ]

# set_property PACKAGE_PIN AT16 [ get_ports spw_dout_p[2] ]
# set_property PACKAGE_PIN AR17 [ get_ports spw_dout_n[2] ]

# set_property PACKAGE_PIN AU20 [ get_ports spw_sout_p[2] ]
# set_property PACKAGE_PIN AU19 [ get_ports spw_sout_n[2] ]


# !! NOTE !! WRONG IO for STAR-Dundee - it requires VADJ 1.8 - 3.3 V
# set_property IOSTANDARD DIFF_SSTL12 [ get_ports spw_din_p[1] ]
# set_property IOSTANDARD DIFF_SSTL12 [ get_ports spw_din_n[1] ]
# set_property IOSTANDARD DIFF_SSTL12 [ get_ports spw_din_p[2] ]
# set_property IOSTANDARD DIFF_SSTL12 [ get_ports spw_din_n[2] ]

# set_property IOSTANDARD DIFF_SSTL12 [ get_ports spw_sin_p[1] ]
# set_property IOSTANDARD DIFF_SSTL12 [ get_ports spw_sin_n[1] ]
# set_property IOSTANDARD DIFF_SSTL12 [ get_ports spw_sin_p[2] ]
# set_property IOSTANDARD DIFF_SSTL12 [ get_ports spw_sin_n[2] ]

# set_property IOSTANDARD SSTL12 [ get_ports spw_dout_p[1] ]
# set_property IOSTANDARD SSTL12 [ get_ports spw_dout_n[1] ]
# set_property IOSTANDARD SSTL12 [ get_ports spw_dout_p[2] ]
# set_property IOSTANDARD SSTL12 [ get_ports spw_dout_n[2] ]

# set_property IOSTANDARD SSTL12 [ get_ports spw_sout_p[1] ]
# set_property IOSTANDARD SSTL12 [ get_ports spw_sout_n[1] ]
# set_property IOSTANDARD SSTL12 [ get_ports spw_sout_p[2] ]
# set_property IOSTANDARD SSTL12 [ get_ports spw_sout_n[2] ]


# --- FMC (NF2) ---------------------------------------

# C connector
# set_property PACKAGE_PIN AR20 [get_ports Dq_Io_1[4]]
# set_property PACKAGE_PIN AT20 [get_ports Dq_Io_1[2]]
# set_property PACKAGE_PIN AR17 [get_ports Wr_Re_0_n]
# set_property PACKAGE_PIN AT16 [get_ports Dq_Io_1[3]]
# set_property PACKAGE_PIN AV17 [get_ports Dq_Io_1[5]]
# set_property PACKAGE_PIN AU17 [get_ports Dq_Io_1[0]]
# set_property PACKAGE_PIN BD17 [get_ports Dq_Io_1[1]]
# set_property PACKAGE_PIN BE17 [get_ports Clk_We_1_n]
# set_property PACKAGE_PIN BE24 [get_ports Dq_Io_1[6]]

# set_property PACKAGE_PIN K8  [get_ports ]        # C15  RE_0_C   Wr_Re_n


# D connector
# set_property PACKAGE_PIN AP18 [get_ports Dq_Io_1[7]]
# set_property PACKAGE_PIN AP19 [get_ports Ale_1]
# set_property PACKAGE_PIN AM17 [get_ports Cle_1]
# set_property PACKAGE_PIN AL16 [get_ports Wp_1_n]
# set_property PACKAGE_PIN AN17 [get_ports Ce1_1_n]
# set_property PACKAGE_PIN AM18 [get_ports Ce0_1_n]
# set_property PACKAGE_PIN AU19 [get_ports Rb0_0_n]
# set_property PACKAGE_PIN AU20 [get_ports Rb1_0_n]
# set_property PACKAGE_PIN BC16 [get_ports Rb1_1_n]
# set_property PACKAGE_PIN BB16 [get_ports Rb0_1_n]
# set_property PACKAGE_PIN BD18 [get_ports Wr_Re_1_n]

# set_property PACKAGE_PIN F20 [get_ports ]          # D27  RE_1_C


# G connector
# set_property PACKAGE_PIN AY18 [get_ports Ce0_0_n]
# set_property PACKAGE_PIN AW19 [get_ports Ce1_0_n]
# set_property PACKAGE_PIN AN19 [get_ports Wp_0_n]
# set_property PACKAGE_PIN AN20 [get_ports Cle_0]
# set_property PACKAGE_PIN AU16 [get_ports Ale_0]
# set_property PACKAGE_PIN AT17 [get_ports Dq_Io_0[7]]
# set_property PACKAGE_PIN AY19 [get_ports Dq_Io_0[6]]
# set_property PACKAGE_PIN AW20 [get_ports Clk_We_0_n]
# set_property PACKAGE_PIN BA19 [get_ports Dq_Io_0[1]]
# set_property PACKAGE_PIN BA20 [get_ports Dq_Io_0[0]]
# set_property PACKAGE_PIN BC17 [get_ports Dq_Io_0[5]]
# set_property PACKAGE_PIN BB18 [get_ports Dq_Io_0[2]]
# set_property PACKAGE_PIN BE20 [get_ports Dq_Io_0[4]]
# set_property PACKAGE_PIN BE21 [get_ports Dq_Io_0[3]]


# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_1[4]]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_1[2]]
# set_property IOSTANDARD LVCMOS12 [get_ports Wr_Re_0_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_1[3]]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_1[5]]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_1[0]]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_1[1]]
# set_property IOSTANDARD LVCMOS12 [get_ports Clk_We_1_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_1[6]]

# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_1[7]]
# set_property IOSTANDARD LVCMOS12 [get_ports Ale_1]
# set_property IOSTANDARD LVCMOS12 [get_ports Cle_1]
# set_property IOSTANDARD LVCMOS12 [get_ports Wp_1_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Ce1_1_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Ce0_1_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Rb0_0_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Rb1_0_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Rb1_1_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Rb0_1_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Wr_Re_1_n]

# set_property IOSTANDARD LVCMOS12 [get_ports Ce0_0_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Ce1_0_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Wp_0_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Cle_0]
# set_property IOSTANDARD LVCMOS12 [get_ports Ale_0]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_0[7]]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_0[6]]
# set_property IOSTANDARD LVCMOS12 [get_ports Clk_We_0_n]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_0[1]]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_0[0]]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_0[5]]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_0[2]]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_0[4]]
# set_property IOSTANDARD LVCMOS12 [get_ports Dq_Io_0[3]]


# --- DDR4 --------------------------------

set_property PACKAGE_PIN AF37 [get_ports {ddr4_rtl_0_act_n[0]}]
set_property PACKAGE_PIN AE38 [get_ports {ddr4_rtl_0_adr[0]}]
set_property PACKAGE_PIN AF38 [get_ports {ddr4_rtl_0_adr[10]}]
set_property PACKAGE_PIN AD42 [get_ports {ddr4_rtl_0_adr[11]}]
set_property PACKAGE_PIN AF46 [get_ports {ddr4_rtl_0_adr[12]}]
set_property PACKAGE_PIN AF43 [get_ports {ddr4_rtl_0_adr[13]}]
set_property PACKAGE_PIN AJ40 [get_ports {ddr4_rtl_0_adr[14]}]
set_property PACKAGE_PIN AH41 [get_ports {ddr4_rtl_0_adr[15]}]
set_property PACKAGE_PIN AD37 [get_ports {ddr4_rtl_0_adr[16]}]
set_property PACKAGE_PIN AD41 [get_ports {ddr4_rtl_0_adr[1]}]
set_property PACKAGE_PIN AE40 [get_ports {ddr4_rtl_0_adr[2]}]
set_property PACKAGE_PIN AG37 [get_ports {ddr4_rtl_0_adr[3]}]
set_property PACKAGE_PIN AF39 [get_ports {ddr4_rtl_0_adr[4]}]
set_property PACKAGE_PIN AF42 [get_ports {ddr4_rtl_0_adr[5]}]
set_property PACKAGE_PIN AE42 [get_ports {ddr4_rtl_0_adr[6]}]
set_property PACKAGE_PIN AG44 [get_ports {ddr4_rtl_0_adr[7]}]
set_property PACKAGE_PIN AD43 [get_ports {ddr4_rtl_0_adr[8]}]
set_property PACKAGE_PIN AC37 [get_ports {ddr4_rtl_0_adr[9]}]
set_property PACKAGE_PIN AH38 [get_ports {ddr4_rtl_0_ba[0]}]
set_property PACKAGE_PIN AF40 [get_ports {ddr4_rtl_0_ba[1]}]
set_property PACKAGE_PIN AG39 [get_ports {ddr4_rtl_0_bg[0]}]
set_property PACKAGE_PIN AG41 [get_ports {ddr4_rtl_0_ck_t[0]}]
set_property PACKAGE_PIN AF41 [get_ports {ddr4_rtl_0_ck_c[0]}]
set_property PACKAGE_PIN AD38 [get_ports {ddr4_rtl_0_cke[0]}]
set_property PACKAGE_PIN AH40 [get_ports {ddr4_rtl_0_cs_n[0]}]
set_property PACKAGE_PIN AH43 [get_ports {ddr4_rtl_0_dm_n[0]}]
set_property PACKAGE_PIN AF47 [get_ports {ddr4_rtl_0_dm_n[1]}]
set_property PACKAGE_PIN AK40 [get_ports {ddr4_rtl_0_dm_n[2]}]
set_property PACKAGE_PIN AN46 [get_ports {ddr4_rtl_0_dm_n[3]}]
set_property PACKAGE_PIN AT47 [get_ports {ddr4_rtl_0_dm_n[4]}]
set_property PACKAGE_PIN AP40 [get_ports {ddr4_rtl_0_dm_n[5]}]
set_property PACKAGE_PIN BB46 [get_ports {ddr4_rtl_0_dm_n[6]}]
set_property PACKAGE_PIN AY45 [get_ports {ddr4_rtl_0_dm_n[7]}]
set_property PACKAGE_PIN AY42 [get_ports {ddr4_rtl_0_dm_n[8]}]
set_property PACKAGE_PIN AJ45 [get_ports {ddr4_rtl_0_dq[0]}]
set_property PACKAGE_PIN AH47 [get_ports {ddr4_rtl_0_dq[10]}]
set_property PACKAGE_PIN AD45 [get_ports {ddr4_rtl_0_dq[11]}]
set_property PACKAGE_PIN AK46 [get_ports {ddr4_rtl_0_dq[12]}]
set_property PACKAGE_PIN AD47 [get_ports {ddr4_rtl_0_dq[13]}]
set_property PACKAGE_PIN AK47 [get_ports {ddr4_rtl_0_dq[14]}]
set_property PACKAGE_PIN AE47 [get_ports {ddr4_rtl_0_dq[15]}]
set_property PACKAGE_PIN AK38 [get_ports {ddr4_rtl_0_dq[16]}]
set_property PACKAGE_PIN AM41 [get_ports {ddr4_rtl_0_dq[17]}]
set_property PACKAGE_PIN AL37 [get_ports {ddr4_rtl_0_dq[18]}]
set_property PACKAGE_PIN AM40 [get_ports {ddr4_rtl_0_dq[19]}]
set_property PACKAGE_PIN AE44 [get_ports {ddr4_rtl_0_dq[1]}]
set_property PACKAGE_PIN AK37 [get_ports {ddr4_rtl_0_dq[20]}]
set_property PACKAGE_PIN AL41 [get_ports {ddr4_rtl_0_dq[21]}]
set_property PACKAGE_PIN AM39 [get_ports {ddr4_rtl_0_dq[22]}]
set_property PACKAGE_PIN AM38 [get_ports {ddr4_rtl_0_dq[23]}]
set_property PACKAGE_PIN AL46 [get_ports {ddr4_rtl_0_dq[24]}]
set_property PACKAGE_PIN AN47 [get_ports {ddr4_rtl_0_dq[25]}]
set_property PACKAGE_PIN AL47 [get_ports {ddr4_rtl_0_dq[26]}]
set_property PACKAGE_PIN AM46 [get_ports {ddr4_rtl_0_dq[27]}]
set_property PACKAGE_PIN AL44 [get_ports {ddr4_rtl_0_dq[28]}]
set_property PACKAGE_PIN AM45 [get_ports {ddr4_rtl_0_dq[29]}]
set_property PACKAGE_PIN AJ44 [get_ports {ddr4_rtl_0_dq[2]}]
set_property PACKAGE_PIN AL43 [get_ports {ddr4_rtl_0_dq[30]}]
set_property PACKAGE_PIN AM44 [get_ports {ddr4_rtl_0_dq[31]}]
set_property PACKAGE_PIN AR44 [get_ports {ddr4_rtl_0_dq[32]}]
set_property PACKAGE_PIN AT44 [get_ports {ddr4_rtl_0_dq[33]}]
set_property PACKAGE_PIN AU44 [get_ports {ddr4_rtl_0_dq[34]}]
set_property PACKAGE_PIN AP44 [get_ports {ddr4_rtl_0_dq[35]}]
set_property PACKAGE_PIN AR45 [get_ports {ddr4_rtl_0_dq[36]}]
set_property PACKAGE_PIN AP43 [get_ports {ddr4_rtl_0_dq[37]}]
set_property PACKAGE_PIN AU46 [get_ports {ddr4_rtl_0_dq[38]}]
set_property PACKAGE_PIN AU45 [get_ports {ddr4_rtl_0_dq[39]}]
set_property PACKAGE_PIN AD44 [get_ports {ddr4_rtl_0_dq[3]}]
set_property PACKAGE_PIN AT40 [get_ports {ddr4_rtl_0_dq[40]}]
set_property PACKAGE_PIN AR39 [get_ports {ddr4_rtl_0_dq[41]}]
set_property PACKAGE_PIN AT41 [get_ports {ddr4_rtl_0_dq[42]}]
set_property PACKAGE_PIN AT39 [get_ports {ddr4_rtl_0_dq[43]}]
set_property PACKAGE_PIN AN38 [get_ports {ddr4_rtl_0_dq[44]}]
set_property PACKAGE_PIN AN40 [get_ports {ddr4_rtl_0_dq[45]}]
set_property PACKAGE_PIN AM37 [get_ports {ddr4_rtl_0_dq[46]}]
set_property PACKAGE_PIN AP39 [get_ports {ddr4_rtl_0_dq[47]}]
set_property PACKAGE_PIN BC46 [get_ports {ddr4_rtl_0_dq[48]}]
set_property PACKAGE_PIN AV46 [get_ports {ddr4_rtl_0_dq[49]}]
set_property PACKAGE_PIN AK44 [get_ports {ddr4_rtl_0_dq[4]}]
set_property PACKAGE_PIN BC47 [get_ports {ddr4_rtl_0_dq[50]}]
set_property PACKAGE_PIN AW47 [get_ports {ddr4_rtl_0_dq[51]}]
set_property PACKAGE_PIN BD47 [get_ports {ddr4_rtl_0_dq[52]}]
set_property PACKAGE_PIN AV47 [get_ports {ddr4_rtl_0_dq[53]}]
set_property PACKAGE_PIN BE46 [get_ports {ddr4_rtl_0_dq[54]}]
set_property PACKAGE_PIN AY46 [get_ports {ddr4_rtl_0_dq[55]}]
set_property PACKAGE_PIN BD45 [get_ports {ddr4_rtl_0_dq[56]}]
set_property PACKAGE_PIN AW44 [get_ports {ddr4_rtl_0_dq[57]}]
set_property PACKAGE_PIN BC45 [get_ports {ddr4_rtl_0_dq[58]}]
set_property PACKAGE_PIN AY44 [get_ports {ddr4_rtl_0_dq[59]}]
set_property PACKAGE_PIN AE45 [get_ports {ddr4_rtl_0_dq[5]}]
set_property PACKAGE_PIN BE45 [get_ports {ddr4_rtl_0_dq[60]}]
set_property PACKAGE_PIN AW45 [get_ports {ddr4_rtl_0_dq[61]}]
set_property PACKAGE_PIN BD44 [get_ports {ddr4_rtl_0_dq[62]}]
set_property PACKAGE_PIN AV45 [get_ports {ddr4_rtl_0_dq[63]}]
set_property PACKAGE_PIN BC42 [get_ports {ddr4_rtl_0_dq[64]}]
set_property PACKAGE_PIN AW43 [get_ports {ddr4_rtl_0_dq[65]}]
set_property PACKAGE_PIN BC43 [get_ports {ddr4_rtl_0_dq[66]}]
set_property PACKAGE_PIN AW42 [get_ports {ddr4_rtl_0_dq[67]}]
set_property PACKAGE_PIN BD42 [get_ports {ddr4_rtl_0_dq[68]}]
set_property PACKAGE_PIN AV42 [get_ports {ddr4_rtl_0_dq[69]}]
set_property PACKAGE_PIN AK45 [get_ports {ddr4_rtl_0_dq[6]}]
set_property PACKAGE_PIN BE42 [get_ports {ddr4_rtl_0_dq[70]}]
set_property PACKAGE_PIN AV43 [get_ports {ddr4_rtl_0_dq[71]}]
set_property PACKAGE_PIN AF44 [get_ports {ddr4_rtl_0_dq[7]}]
set_property PACKAGE_PIN AJ47 [get_ports {ddr4_rtl_0_dq[8]}]
set_property PACKAGE_PIN AE46 [get_ports {ddr4_rtl_0_dq[9]}]
set_property PACKAGE_PIN AH45 [get_ports {ddr4_rtl_0_dqs_t[0]}]
set_property PACKAGE_PIN AG45 [get_ports {ddr4_rtl_0_dqs_c[0]}]
set_property PACKAGE_PIN AH46 [get_ports {ddr4_rtl_0_dqs_t[1]}]
set_property PACKAGE_PIN AG46 [get_ports {ddr4_rtl_0_dqs_c[1]}]
set_property PACKAGE_PIN AL39 [get_ports {ddr4_rtl_0_dqs_t[2]}]
set_property PACKAGE_PIN AK39 [get_ports {ddr4_rtl_0_dqs_c[2]}]
set_property PACKAGE_PIN AP45 [get_ports {ddr4_rtl_0_dqs_t[3]}]
set_property PACKAGE_PIN AN45 [get_ports {ddr4_rtl_0_dqs_c[3]}]
set_property PACKAGE_PIN AR46 [get_ports {ddr4_rtl_0_dqs_t[4]}]
set_property PACKAGE_PIN AT46 [get_ports {ddr4_rtl_0_dqs_c[4]}]
set_property PACKAGE_PIN AR42 [get_ports {ddr4_rtl_0_dqs_t[5]}]
set_property PACKAGE_PIN AR41 [get_ports {ddr4_rtl_0_dqs_c[5]}]
set_property PACKAGE_PIN AY47 [get_ports {ddr4_rtl_0_dqs_t[6]}]
set_property PACKAGE_PIN BA46 [get_ports {ddr4_rtl_0_dqs_c[6]}]
set_property PACKAGE_PIN BB44 [get_ports {ddr4_rtl_0_dqs_t[7]}]
set_property PACKAGE_PIN BB45 [get_ports {ddr4_rtl_0_dqs_c[7]}]
set_property PACKAGE_PIN BB43 [get_ports {ddr4_rtl_0_dqs_t[8]}]
set_property PACKAGE_PIN BA42 [get_ports {ddr4_rtl_0_dqs_c[8]}]
set_property PACKAGE_PIN AD39 [get_ports {ddr4_rtl_0_odt[0]}]
set_property PACKAGE_PIN AK42 [get_ports {ddr4_rtl_0_reset_n[0]}]
set_property PACKAGE_PIN AM43 [get_ports {sys_clk_0_clk_p[0]}]
set_property PACKAGE_PIN AN43 [get_ports {sys_clk_0_clk_n[0]}]


# --- Programming/bitstream --------------------------------

# Configuration from SPI Flash as per XAPP1233
# Enable bitstream compression
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# Don't pull unused pins up or down
#set_property BITSTREAM.CONFIG.UNUSEDPIN {Pullnone} [current_design]

# Set CFGBVS to GND to match schematics
set_property CFGBVS GND [current_design]

# Set CONFIG_VOLTAGE to 1.8V to match schematics
set_property CONFIG_VOLTAGE 1.8 [current_design]

set_property DELAY_VALUE_XPHY 0 [get_ports clk300n]
