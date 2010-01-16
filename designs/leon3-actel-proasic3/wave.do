onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /testbench/clk
add wave -noupdate -format Logic /testbench/rst
add wave -noupdate -format Literal -radix hexadecimal /testbench/address
add wave -noupdate -format Literal -radix hexadecimal /testbench/data
add wave -noupdate -format Logic /testbench/ramsn
add wave -noupdate -format Logic /testbench/ramoen
add wave -noupdate -format Logic /testbench/rwen
add wave -noupdate -format Literal /testbench/ramben
add wave -noupdate -format Logic /testbench/romsn
add wave -noupdate -format Logic /testbench/iosn
add wave -noupdate -format Logic /testbench/oen
add wave -noupdate -format Logic /testbench/writen
add wave -noupdate -format Literal /testbench/gpio
add wave -noupdate -format Logic /testbench/txd1
add wave -noupdate -format Logic /testbench/rxd1
add wave -noupdate -format Logic /testbench/etx_clk
add wave -noupdate -format Logic /testbench/erx_clk
add wave -noupdate -format Logic /testbench/erx_dv
add wave -noupdate -format Logic /testbench/erx_er
add wave -noupdate -format Logic /testbench/erx_col
add wave -noupdate -format Logic /testbench/erx_crs
add wave -noupdate -format Logic /testbench/etx_en
add wave -noupdate -format Logic /testbench/etx_er
add wave -noupdate -format Literal /testbench/erxd
add wave -noupdate -format Literal /testbench/etxd
add wave -noupdate -format Logic /testbench/emdc
add wave -noupdate -format Logic /testbench/emdio
add wave -noupdate -format Logic /testbench/can_txd
add wave -noupdate -format Logic /testbench/can_rxd
add wave -noupdate -format Logic /testbench/ramclk
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/apbi
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/apbo
add wave -noupdate -format Literal -radix hexadecimal -expand /testbench/d3/ahbsi
add wave -noupdate -format Logic /testbench/d3/clkm
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/ahbso
add wave -noupdate -format Literal -radix hexadecimal -expand /testbench/d3/ahbmi
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/ahbmo
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/l3/cpu__0/l3ft/leon3ft0/beh/p0/iuft0/ici
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/l3/cpu__0/l3ft/leon3ft0/beh/p0/iuft0/ico
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/l3/cpu__0/l3ft/leon3ft0/beh/p0/iuft0/dci
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/l3/cpu__0/l3ft/leon3ft0/beh/p0/iuft0/dco
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/l3/cpu__0/l3ft/leon3ft0/beh/p0/iuft0/rfi
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/l3/cpu__0/l3ft/leon3ft0/beh/p0/iuft0/rfo
add wave -noupdate -format Literal -radix hexadecimal /testbench/d3/l3/cpu__0/l3ft/leon3ft0/beh/p0/iuft0/r
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {499173706 ps} 0}
configure wave -namecolwidth 179
configure wave -valuecolwidth 100
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
WaveRestoreZoom {498938215 ps} {499603086 ps}
