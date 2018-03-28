onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /testbench/clk
add wave -noupdate -format Logic /testbench/rst
add wave -noupdate -format Literal -radix hexadecimal /testbench/address
add wave -noupdate -format Literal -radix hexadecimal /testbench/data
add wave -noupdate -format Literal /testbench/romsn
add wave -noupdate -format Logic /testbench/oen
add wave -noupdate -format Logic /testbench/writen
add wave -noupdate -format Logic /testbench/ddr_clk
add wave -noupdate -format Logic /testbench/ddr_clkb
add wave -noupdate -format Logic /testbench/ddr_cke
add wave -noupdate -format Logic /testbench/d3/clkm
add wave -noupdate -format Logic /testbench/ddr_csb
add wave -noupdate -format Logic /testbench/ddr_web
add wave -noupdate -format Logic /testbench/ddr_rasb
add wave -noupdate -format Logic /testbench/ddr_casb
add wave -noupdate -format Literal /testbench/ddr_dm
add wave -noupdate -format Literal /testbench/ddr_dqs
add wave -noupdate -format Literal -radix hexadecimal /testbench/ddr_ad
add wave -noupdate -format Literal -radix hexadecimal /testbench/ddr_ba
add wave -noupdate -format Literal -radix hexadecimal /testbench/ddr_dq
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/sdi
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/sdo
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/ahbsi
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/ahbso
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/ahbmi
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/ahbmo
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/apbi
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/apbo
add wave -noupdate -format Logic /testbench/d3/ddrsp0/ddrc/clk_ddr
add wave -noupdate -format Logic /testbench/d3/ddrsp0/ddrc/clk_ahb
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/ddrsp0/ddrc/ddr16/ddrc/r
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/ddrsp0/ddrc/ddr16/ddrc/ra
add wave -noupdate -format Logic /testbench/ddr_clk_fb
add wave -noupdate -format Logic /testbench/d3/clkml
add wave -noupdate -format Logic /testbench/d3/ddrsp0/ddrc/ddr16/ddrc/clkread
add wave -noupdate -format Logic /testbench/d3/ddrsp0/ddrc/ddr_phy0/xc3se/ddr_phy0/rclk270b
add wave -noupdate -format Logic /testbench/d3/ddrsp0/ddrc/ddr_phy0/xc3se/ddr_phy0/rclk90b
add wave -noupdate -format Logic /testbench/d3/ddrsp0/ddrc/ddr_phy0/xc3se/ddr_phy0/rclk0b
add wave -noupdate -format Logic -radix hexadecimal /testbench/d3/ddrsp0/ddrc/ddr16/ddrc/rwrite
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/ddrsp0/ddrc/ddr16/ddrc/rwdata
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/ddrsp0/ddrc/ddr16/ddrc/waddr2
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {71438500 ps} 0} {{Cursor 3} {71441600 ps} 0}
configure wave -namecolwidth 234
configure wave -valuecolwidth 77
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
update
WaveRestoreZoom {71401059 ps} {71460931 ps}
