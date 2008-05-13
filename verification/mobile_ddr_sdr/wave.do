onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider DDR
add wave -noupdate -group {DDR ctrl}
add wave -noupdate -group {DDR ctrl} -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/rst
add wave -noupdate -group {DDR ctrl} -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/clk_ddr
add wave -noupdate -group {DDR ctrl} -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/clk_ahb
add wave -noupdate -group {DDR ctrl} -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/clkread
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/ahbsi
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/ahbso
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/sdi
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/sdo
add wave -noupdate -group {DDR ctrl} -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/vcc
add wave -noupdate -group {DDR ctrl} -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/rwrite
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/r
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/ri
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/ra
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/rai
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/rdata
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/wdata
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/rwdata
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/rbdrive
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/ribdrive
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/waddr2
add wave -noupdate -group {DDR ctrl} -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/ddr_rst
add wave -noupdate -group {DDR ctrl} -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr16/ddrc/ddr_rst_gen
add wave -noupdate -divider {DDR Signals}
add wave -noupdate -format Logic /testbench/ddr_clk_fb
add wave -noupdate -format Logic /testbench/ddr_clk
add wave -noupdate -format Logic /testbench/ddr_clkb
add wave -noupdate -format Literal /testbench/ddr_ad
add wave -noupdate -format Literal /testbench/ddr_ba
add wave -noupdate -format Logic /testbench/ddr_cke
add wave -noupdate -format Logic /testbench/ddr_csb
add wave -noupdate -format Logic /testbench/ddr_rasb
add wave -noupdate -format Logic /testbench/ddr_casb
add wave -noupdate -format Logic /testbench/ddr_web
add wave -noupdate -format Literal /testbench/ddr_dm
add wave -noupdate -format Literal -radix hexadecimal /testbench/ddr_dq
add wave -noupdate -format Literal /testbench/ddr_dqs
add wave -noupdate -divider {DDR PHY}
add wave -noupdate -group DDR_PHY
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/rst
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/clk
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/clkout
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/lock
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_clk
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_clkb
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_clk_fb_out
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_clk_fb
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_cke
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_csb
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_web
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_rasb
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_casb
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_dm
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_dqs
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_ad
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_ba
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_dq
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/addr
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ba
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/dqin
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/dqout
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/dm
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/oen
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/dqs
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/dqsoen
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/rasn
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/casn
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/wen
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/csn
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/cke
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ck
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/moben
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/vcc
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/gnd
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/clk0r
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/clk90r
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/clk180r
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/clk270r
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/rclk90r
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/rclk270r
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_clkl
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_clkbl
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ckn
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_rasnr
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_casnr
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_wenr
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_csnr
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_ckenr
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ckel
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_adr
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_bar
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/dqsn
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/oe
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_dqsin
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_dqsoen
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_dqsoutl
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_dmr
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_dqin
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_dqout
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/ddr_dqoen
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/dqinl
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/dqinl2
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/dqinl3
add wave -noupdate -group DDR_PHY -format Literal -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/dqinl4
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/lockl
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/locked
add wave -noupdate -group DDR_PHY -format Logic -height 20 /testbench/cpu/ddrsp0/ddrc0/ddr_phy0/ddr_phy0/inf/ddr_phy0/vlockl
add wave -noupdate -divider SDCTRL
add wave -noupdate -format Logic /testbench/cpu/sd1/sdc/ctrl/startsd
add wave -noupdate -group SDC
add wave -noupdate -group SDC -format Logic -height 20 /testbench/cpu/sd1/sdc/rst
add wave -noupdate -group SDC -format Logic -height 20 /testbench/cpu/sd1/sdc/clk
add wave -noupdate -group SDC -format Literal -height 20 -expand /testbench/cpu/sd1/sdc/ahbsi
add wave -noupdate -group SDC -format Literal -height 20 -expand /testbench/cpu/sd1/sdc/ahbso
add wave -noupdate -group SDC -format Literal -height 20 /testbench/cpu/sd1/sdc/sdi
add wave -noupdate -group SDC -format Literal -height 20 /testbench/cpu/sd1/sdc/sdo
add wave -noupdate -group SDC -format Literal -height 20 -expand /testbench/cpu/sd1/sdc/r
add wave -noupdate -group SDC -format Literal -height 20 /testbench/cpu/sd1/sdc/ri
add wave -noupdate -group SDC -format Literal -height 20 /testbench/cpu/sd1/sdc/rbdrive
add wave -noupdate -group SDC -format Literal -height 20 /testbench/cpu/sd1/sdc/ribdrive
add wave -noupdate -divider {SD signals}
add wave -noupdate -format Logic /testbench/sdclk
add wave -noupdate -format Literal /testbench/sdcke
add wave -noupdate -format Literal /testbench/sdcsn
add wave -noupdate -format Logic /testbench/sdwen
add wave -noupdate -format Logic /testbench/sdrasn
add wave -noupdate -format Logic /testbench/sdcasn
add wave -noupdate -format Literal /testbench/sddqm
add wave -noupdate -format Literal /testbench/sa
add wave -noupdate -format Literal -radix hexadecimal /testbench/sd
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {113683916 ps} 0} {{Cursor 2} {113695964 ps} 0}
configure wave -namecolwidth 205
configure wave -valuecolwidth 115
configure wave -justifyvalue left
configure wave -signalnamewidth 2
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
update
WaveRestoreZoom {113572982 ps} {113920370 ps}
