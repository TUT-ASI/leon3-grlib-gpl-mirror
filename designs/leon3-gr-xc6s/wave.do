onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /testbench/wdogn
add wave -noupdate /testbench/wdogn_local
add wave -noupdate -divider {WDOG PAD}
add wave -noupdate /testbench/cpu/wdogn
add wave -noupdate -divider MIG
add wave -noupdate /testbench/cpu/mig_gen/ddrc/ahbso
add wave -noupdate /testbench/cpu/mig_gen/ddrc/ahbsi
add wave -noupdate /testbench/cpu/mig_gen/ddrc/ahbmi
add wave -noupdate /testbench/cpu/mig_gen/ddrc/ahbmo
add wave -noupdate /testbench/cpu/mig_gen/ddrc/apbi
add wave -noupdate /testbench/cpu/mig_gen/ddrc/apbo
add wave -noupdate /testbench/cpu/mig_gen/ddrc/calib_done
add wave -noupdate /testbench/cpu/mig_gen/ddrc/test_error
add wave -noupdate /testbench/cpu/mig_gen/ddrc/rst_n_syn
add wave -noupdate /testbench/cpu/mig_gen/ddrc/rst_n_async
add wave -noupdate /testbench/cpu/mig_gen/ddrc/clk_amba
add wave -noupdate /testbench/cpu/mig_gen/ddrc/clk_mem_n
add wave -noupdate /testbench/cpu/mig_gen/ddrc/clk_mem_p
add wave -noupdate /testbench/cpu/mig_gen/ddrc/clk_125
add wave -noupdate /testbench/cpu/mig_gen/ddrc/clk_100
add wave -noupdate -divider WDOG
add wave -noupdate /testbench/cpu/resetn
add wave -noupdate /testbench/cpu/rst
add wave -noupdate -divider GPTIMER
add wave -noupdate /testbench/cpu/gpt/timer0/pindex
add wave -noupdate /testbench/cpu/gpt/timer0/paddr
add wave -noupdate /testbench/cpu/gpt/timer0/pmask
add wave -noupdate /testbench/cpu/gpt/timer0/pirq
add wave -noupdate /testbench/cpu/gpt/timer0/sepirq
add wave -noupdate /testbench/cpu/gpt/timer0/sbits
add wave -noupdate /testbench/cpu/gpt/timer0/ntimers
add wave -noupdate /testbench/cpu/gpt/timer0/nbits
add wave -noupdate /testbench/cpu/gpt/timer0/wdog
add wave -noupdate /testbench/cpu/gpt/timer0/ewdogen
add wave -noupdate /testbench/cpu/gpt/timer0/rst
add wave -noupdate /testbench/cpu/gpt/timer0/clk
add wave -noupdate /testbench/cpu/gpt/timer0/apbi
add wave -noupdate /testbench/cpu/gpt/timer0/apbo
add wave -noupdate /testbench/cpu/gpt/timer0/gpti
add wave -noupdate /testbench/cpu/gpt/timer0/gpto
add wave -noupdate /testbench/cpu/gpt/timer0/r
add wave -noupdate /testbench/cpu/gpt/timer0/rin
add wave -noupdate /testbench/cpu/gpt/timer0/REVISION
add wave -noupdate /testbench/cpu/gpt/timer0/pconfig
add wave -noupdate /testbench/cpu/gpt/timer0/TBITS
add wave -noupdate /testbench/cpu/gpt/timer0/NMI
add wave -noupdate /testbench/cpu/gpt/timer0/RESET_ALL
add wave -noupdate /testbench/cpu/gpt/timer0/RESVAL
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {578161251 ps} 0}
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 2
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 1
configure wave -timelineunits ns
update
WaveRestoreZoom {575334046 ps} {606486148 ps}
