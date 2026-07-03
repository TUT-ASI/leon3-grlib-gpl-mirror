#
# Clocks
#
#
# Inputs/Outputs
#
#
# Registers
#
#
# Multicycle Path
#
#
# False Path
#
#
# Attributes
#
#define_global_attribute          syn_useioff {1}
#
# Other Constraints
#
create_clock -name {clk_in_125mhz} -period 8 [get_ports clk_in_125mhz]
create_clock -name {clkm} -period 20 [get_nets clkm]
create_clock -name {clk100} -period 10 [get_nets clk100]
create_clock -name {clk200} -period 5 [get_nets clk200]
create_clock -name {fpga_pci_clk} -period 30.3030303030303 [get_ports fpga_pci_clk]
# JTAG CLOCK
# Arbitrarily assign a 10 MHz clock signal on the dedicated JTAG clock pin.
# In practice this clock is completely asynchronous to clkm since it is
# provided by an external debugger/USB-serial converter. And there is an
# internal clock-domain crossing between the clkm and tck clock domains.
# But simply marking the clock domains as asynchronous with a constraint is
# not appropriate because that simply ignores timing between the domains and
# it has been observed that (without timing constraints) Radiant will
# occasionally place the AHBJTAG far enough away from the JTAG macro that the
# routing delay is too large and causes the clock-domain crossing to become
# unreliable.
# An alternative could be set_max_delay, but the results were not encouraging.
# Instead we enforce a reasonable timing constraint by setting the TCK frequency
# to be a submultiple of the clkm frequency. In the absence of other constraints,
# Synplify will consider tck and clkm synchronous and find that the worst-case
# separation of two clock edges is one clkm-period and will constrain propagation
# delays to be roughly within one clkm-period in both directions. This should be
# sufficient to make the AHBJTAG clock-domain transition reliable. However, if the
# clkm-frequency is changed, it is important to update the tck-constraint as well
# to keep the tck-frequency a submultiple of the clkm-frequency.
create_clock -name {tck} -period 100 [get_ports tck]
create_clock -name {eth_rxclk} -period 8 [get_ports eth_rxclk]
create_clock -name {eth_txclk} -period 40 [get_ports eth_txclk]
#DISABLED# set_false_path -from [get_clocks eth_rxclk] -to [get_clocks clkm]
create_clock -name {SD_EXT0_REFCLKP} -period 6.4 [get_ports SD_EXT0_REFCLKP]
create_clock -name {SD_EXT1_REFCLKP} -period 6.4 [get_ports SD_EXT1_REFCLKP]
set_false_path -from [get_clocks fpga_pci_clk] -to [get_clocks clkm]
set_false_path -from [get_clocks clkm] -to [get_clocks fpga_pci_clk]
# On going, timing viaolation on nandflash
#set_max_delay -from [get_clocks clkm] -to [get_clocks clk_in_125mhz] -datapath_only 8
#set_max_delay -from [get_clocks clk_in_125mhz] -to [get_clocks clkm] -datapath_only 8
#set_max_delay -from [get_clocks rgmii_pl0_rx_clk] -to [get_clocks clkm] -datapath_only 8
#set_max_delay -from [get_clocks clkm] -to [get_clocks rgmii_pl0_rx_clk] -datapath_only 8
#set_max_delay -from [get_clocks rgmii_pl0_rx_clk] -to [get_clocks clk25] -datapath_only 8
#set_max_delay -from [get_clocks clk25] -to [get_clocks rgmii_pl0_rx_clk] -datapath_only 8
#set_max_delay -from [get_clocks eth_tx_clk] -to [get_clocks clkm] -datapath_only 8
#set_max_delay -datapath_only -from [get_clocks clkm] -to  [get_clocks eth_tx_clk]   8
# On going, timing viaolation on nandflash
#set_false_path -from [get_clocks clkm] -to [get_pins {nandfctrl0.nand_phy/nandfi.dq[0][0] nandfctrl0.nand_phy/nandfi.dq[0][1] nandfctrl0.nand_phy/nandfi.dq[0][2] nandfctrl0.nand_phy/nandfi.dq[0][3] nandfctrl0.nand_phy/nandfi.dq[0][4] nandfctrl0.nand_phy/nandfi.dq[0][5] nandfctrl0.nand_phy/nandfi.dq[0][6] nandfctrl0.nand_phy/nandfi.dq[0][7] nandfctrl0.nand_phy/nandfi.dq[1][0] nandfctrl0.nand_phy/nandfi.dq[1][1] nandfctrl0.nand_phy/nandfi.dq[1][2] nandfctrl0.nand_phy/nandfi.dq[1][3] nandfctrl0.nand_phy/nandfi.dq[1][4] nandfctrl0.nand_phy/nandfi.dq[1][5] nandfctrl0.nand_phy/nandfi.dq[1][6] nandfctrl0.nand_phy/nandfi.dq[1][7] nandfctrl0.nand_phy/nandfi.dqs[0] nandfctrl0.nand_phy/nandfi.dqs[1] nandfctrl0.nand_phy/nandfo.dq[0][0] nandfctrl0.nand_phy/nandfo.dq[0][1] nandfctrl0.nand_phy/nandfo.dq[0][2] nandfctrl0.nand_phy/nandfo.dq[0][4] nandfctrl0.nand_phy/nandfo.dq[0][3] nandfctrl0.nand_phy/nandfo.dq[0][5] nandfctrl0.nand_phy/nandfo.dq[0][6] nandfctrl0.nand_phy/nandfo.dq[0][7] nandfctrl0.nand_phy/nandfo.dq[1][0] nandfctrl0.nand_phy/nandfo.dq[1][1] nandfctrl0.nand_phy/nandfo.dq[1][2] nandfctrl0.nand_phy/nandfo.dq[1][3] nandfctrl0.nand_phy/nandfo.dq[1][4] nandfctrl0.nand_phy/nandfo.dq[1][5] nandfctrl0.nand_phy/nandfo.dq[1][7] nandfctrl0.nand_phy/nandfo.dq[1][6]}]
#set_false_path -from [get_pins {nandfctrl0.nand_phy/nandfi.dq[0][0] nandfctrl0.nand_phy/nandfi.dq[0][1] nandfctrl0.nand_phy/nandfi.dq[0][2] nandfctrl0.nand_phy/nandfi.dq[0][3] nandfctrl0.nand_phy/nandfi.dq[0][4] nandfctrl0.nand_phy/nandfi.dq[0][5] nandfctrl0.nand_phy/nandfi.dq[0][6] nandfctrl0.nand_phy/nandfi.dq[0][7] nandfctrl0.nand_phy/nandfi.dq[1][0] nandfctrl0.nand_phy/nandfi.dq[1][1] nandfctrl0.nand_phy/nandfi.dq[1][2] nandfctrl0.nand_phy/nandfi.dq[1][3] nandfctrl0.nand_phy/nandfi.dq[1][4] nandfctrl0.nand_phy/nandfi.dq[1][5] nandfctrl0.nand_phy/nandfi.dq[1][6] nandfctrl0.nand_phy/nandfi.dq[1][7] nandfctrl0.nand_phy/nandfi.dqs[0] nandfctrl0.nand_phy/nandfi.dqs[1] nandfctrl0.nand_phy/nandfo.dq[0][0] nandfctrl0.nand_phy/nandfo.dq[0][1] nandfctrl0.nand_phy/nandfo.dq[0][2] nandfctrl0.nand_phy/nandfo.dq[0][4] nandfctrl0.nand_phy/nandfo.dq[0][3] nandfctrl0.nand_phy/nandfo.dq[0][5] nandfctrl0.nand_phy/nandfo.dq[0][6] nandfctrl0.nand_phy/nandfo.dq[0][7] nandfctrl0.nand_phy/nandfo.dq[1][0] nandfctrl0.nand_phy/nandfo.dq[1][1] nandfctrl0.nand_phy/nandfo.dq[1][2] nandfctrl0.nand_phy/nandfo.dq[1][3] nandfctrl0.nand_phy/nandfo.dq[1][4] nandfctrl0.nand_phy/nandfo.dq[1][5] nandfctrl0.nand_phy/nandfo.dq[1][7] nandfctrl0.nand_phy/nandfo.dq[1][6]}] -to [get_clocks clkm]
#set_multicycle_path -setup -from [get_clocks clkm] -to [get_clocks clk200] 4
#set_multicycle_path -hold -end -from [get_clocks clkm] -to [get_clocks clk200] 3
#set_multicycle_path -setup -from [get_clocks clkm] -to [get_clocks clk200] 4
#set_multicycle_path -hold -end -from [get_clocks clkm] -to [get_clocks clk200] 3
#set_multicycle_path -setup -to [get_ports {Wr_Re_0_n Wr_Re_1_n Dq_Io_0[7] Dq_Io_0[6] Dq_Io_0[5] Dq_Io_0[4] Dq_Io_0[3] Dq_Io_0[2] Dq_Io_0[1] Dq_Io_0[0] Dq_Io_1[7] Dq_Io_1[6] Dq_Io_1[5] Dq_Io_1[4] Dq_Io_1[3] Dq_Io_1[2] Dq_Io_1[1] Dq_Io_1[0] Dqs_t_0 Dqs_t_1}] 0
#set_multicycle_path -hold -to [get_ports {Wr_Re_0_n Wr_Re_1_n Dq_Io_0[7] Dq_Io_0[6] Dq_Io_0[5] Dq_Io_0[4] Dq_Io_0[3] Dq_Io_0[2] Dq_Io_0[1] Dq_Io_0[0] Dq_Io_1[7] Dq_Io_1[6] Dq_Io_1[5] Dq_Io_1[4] Dq_Io_1[3] Dq_Io_1[2] Dq_Io_1[1] Dq_Io_1[0] Dqs_t_0 Dqs_t_1}] 1
#set_output_delay -clock [get_clocks clk200] -max 0.5 [get_ports {Wr_Re_0_n Wr_Re_1_n Dq_Io_0[7] Dq_Io_0[6] Dq_Io_0[5] Dq_Io_0[4] Dq_Io_0[3] Dq_Io_0[2] Dq_Io_0[1] Dq_Io_0[0] Dq_Io_1[7] Dq_Io_1[6] Dq_Io_1[5] Dq_Io_1[4] Dq_Io_1[3] Dq_Io_1[2] Dq_Io_1[1] Dq_Io_1[0] Dqs_t_0 Dqs_t_1}]
#set_output_delay -clock [get_clocks clk200] -min 0.5 [get_ports {Wr_Re_0_n Wr_Re_1_n Dq_Io_0[7] Dq_Io_0[6] Dq_Io_0[5] Dq_Io_0[4] Dq_Io_0[3] Dq_Io_0[2] Dq_Io_0[1] Dq_Io_0[0] Dq_Io_1[7] Dq_Io_1[6] Dq_Io_1[5] Dq_Io_1[4] Dq_Io_1[3] Dq_Io_1[2] Dq_Io_1[1] Dq_Io_1[0] Dqs_t_0 Dqs_t_1}]
#set_input_delay -clock [get_clocks clkm] -min 1 [get_ports {Wr_Re_0_n Wr_Re_1_n Dq_Io_0[7] Dq_Io_0[6] Dq_Io_0[5] Dq_Io_0[4] Dq_Io_0[3] Dq_Io_0[2] Dq_Io_0[1] Dq_Io_0[0] Dq_Io_1[7] Dq_Io_1[6] Dq_Io_1[5] Dq_Io_1[4] Dq_Io_1[3] Dq_Io_1[2] Dq_Io_1[1] Dq_Io_1[0] Dqs_t_0 Dqs_t_1}]
#set_input_delay -clock [get_clocks clkm] -max 2 [get_ports {Wr_Re_0_n Wr_Re_1_n Dq_Io_0[7] Dq_Io_0[6] Dq_Io_0[5] Dq_Io_0[4] Dq_Io_0[3] Dq_Io_0[2] Dq_Io_0[1] Dq_Io_0[0] Dq_Io_1[7] Dq_Io_1[6] Dq_Io_1[5] Dq_Io_1[4] Dq_Io_1[3] Dq_Io_1[2] Dq_Io_1[1] Dq_Io_1[0] Dqs_t_0 Dqs_t_1}]
#set_clock_groups -group [get_clocks {clkm clk200}] -asynchronous
#DISABLED# set_input_delay -clock [get_clocks eth_rxclk] -max 2.5 [get_ports {eth_rxd[7] eth_rxd[6] eth_rxd[5] eth_rxd[4] eth_rxd[3] eth_rxd[2] eth_rxd[1] eth_rxd[0] eth_rxdv eth_rxer}]
#DISABLED# set_input_delay -clock [get_clocks eth_rxclk] -min -0.5 [get_ports {eth_rxd[7] eth_rxd[6] eth_rxd[5] eth_rxd[4] eth_rxd[3] eth_rxd[2] eth_rxd[1] eth_rxd[0] eth_rxdv eth_rxer}]
set_max_delay -from [get_clocks eth_rxclk] -to [get_clocks clkm] 8
set_input_delay -clock [get_clocks eth_rxclk] -max 2.5 [get_ports eth_rxer]
set_max_delay -from [get_clocks eth_txclk] -to [get_clocks clkm] 8
