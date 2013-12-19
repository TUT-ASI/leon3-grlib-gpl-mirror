
# --- Detect if we're running in synthesis or STA

set sta_mode 0
if { $::TimeQuestInfo(nameofexecutable) == "quartus_sta" } {
        set sta_mode 1
} 

# --- Routine to constrain CDC to allow a maximum skew of one clock cycle
#     of the faster clock. For synthesis we just timing-ignore the CDC.

if { !$sta_mode } {
	proc constrain_cdc { clks1 per1 clks2 per2 } {
		set_clock_groups -asynchronous -group $clks1 -group $clks2
	}
} else {
	proc constrain_cdc { clks1 per1 clks2 per2 } {
		set_max_delay -from $clks1 -to $clks2 50.0
		set_max_delay -from $clks2 -to $clks1 50.0
		set_min_delay -from $clks1 -to $clks2 -20.0
		set_min_delay -from $clks2 -to $clks1 -20.0
		set minper [ expr { ($per1>$per2)?$per2:$per1 } ]
		set_max_skew -from_clock $clks1 -to_clock $clks2 $minper
		set_max_skew -from_clock $clks2 -to_clock $clks1 $minper
	}
}


# ---------------------------------------------

# Create clocks

create_clock -period  20.0 OSC_50_BANK2
create_clock -period  20.0 OSC_50_BANK3
create_clock -period  20.0 OSC_50_BANK4
create_clock -period  20.0 OSC_50_BANK5
create_clock -period  20.0 OSC_50_BANK6
create_clock -period  20.0 OSC_50_BANK7
create_clock -period  10.0 PLL_CLKIN_p

derive_pll_clocks

set ahbclks [ get_clocks { clkgen0* } ]

set sgmii_rx_clk [ get_clocks { eth1:bridge0|sgmii2gmii_inst|i_tse_pcs_0|the_altera_tse_pma_lvds_rx|ALTLVDS_RX_component|auto_generated|rx[0]|clk0 } ]

set_false_path -from [get_clocks {\eth1:bridge0|sgmii2gmii_inst|i_tse_pcs_0|the_altera_tse_pma_lvds_rx|ALTLVDS_RX_component|auto_generated|rx[0]|clk0}] -to [get_clocks {clkgen0|\stra3:v|sdclk_pll|\nosd:altpll0|auto_generated|pll1|clk[0]}]

set_false_path -from [get_clocks {\eth1:bridge1|sgmii2gmii_inst|i_tse_pcs_0|the_altera_tse_pma_lvds_rx|ALTLVDS_RX_component|auto_generated|rx[0]|clk0}] -to [get_clocks {clkgen0|\stra3:v|sdclk_pll|\nosd:altpll0|auto_generated|pll1|clk[0]}]