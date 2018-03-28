onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {Testbench top-level}
add wave -noupdate -format Logic -height 15 /testbench/clk
add wave -noupdate -format Logic -height 15 /testbench/clkout
add wave -noupdate -format Logic -height 15 /testbench/pllref
add wave -noupdate -format Logic -height 15 /testbench/rst
add wave -noupdate -format Literal -height 15 /testbench/address
add wave -noupdate -format Literal -height 15 /testbench/data
add wave -noupdate -format Logic -height 15 /testbench/romsn
add wave -noupdate -format Logic -height 15 /testbench/iosn
add wave -noupdate -format Logic -height 15 /testbench/oen
add wave -noupdate -format Logic -height 15 /testbench/writen
add wave -noupdate -format Logic -height 15 /testbench/dsuen
add wave -noupdate -format Logic -height 15 /testbench/dsutx
add wave -noupdate -format Logic -height 15 /testbench/dsurx
add wave -noupdate -format Logic -height 15 /testbench/dsubren
add wave -noupdate -format Logic -height 15 /testbench/dsuact
add wave -noupdate -format Logic -height 15 /testbench/dsurst
add wave -noupdate -format Logic -height 15 /testbench/test
add wave -noupdate -format Logic -height 15 /testbench/error
add wave -noupdate -format Literal -height 15 /testbench/gpio
add wave -noupdate -format Logic -height 15 /testbench/gnd
add wave -noupdate -format Logic -height 15 /testbench/vcc
add wave -noupdate -format Logic -height 15 /testbench/nc
add wave -noupdate -format Logic -height 15 /testbench/clk2
add wave -noupdate -format Logic -height 15 /testbench/ssram_cen
add wave -noupdate -format Logic -height 15 /testbench/ssram_wen
add wave -noupdate -format Literal -height 15 /testbench/ssram_bw
add wave -noupdate -format Logic -height 15 /testbench/ssram_oen
add wave -noupdate -format Logic -height 15 /testbench/ssram_clk
add wave -noupdate -format Logic -height 15 /testbench/ssram_adscn
add wave -noupdate -format Logic -height 15 /testbench/ssram_adsp_n
add wave -noupdate -format Logic -height 15 /testbench/ssram_adv_n
add wave -noupdate -format Literal -height 15 /testbench/datazz
add wave -noupdate -format Logic -height 15 /testbench/ddr_clk
add wave -noupdate -format Logic -height 15 /testbench/ddr_clkb
add wave -noupdate -format Logic -height 15 /testbench/ddr_clkin
add wave -noupdate -format Logic -height 15 /testbench/ddr_cke
add wave -noupdate -format Logic -height 15 /testbench/ddr_csb
add wave -noupdate -format Logic -height 15 /testbench/ddr_web
add wave -noupdate -format Logic -height 15 /testbench/ddr_rasb
add wave -noupdate -format Logic -height 15 /testbench/ddr_casb
add wave -noupdate -format Literal -height 15 /testbench/ddr_dm
add wave -noupdate -format Literal -height 15 /testbench/ddr_dqs
add wave -noupdate -format Literal -height 15 /testbench/ddr_ad
add wave -noupdate -format Literal -height 15 /testbench/ddr_ba
add wave -noupdate -format Literal -height 15 /testbench/ddr_dq
add wave -noupdate -format Logic -height 15 /testbench/hc_vd
add wave -noupdate -format Logic -height 15 /testbench/hc_hd
add wave -noupdate -format Logic -height 15 /testbench/hc_den
add wave -noupdate -format Logic -height 15 /testbench/hc_nclk
add wave -noupdate -format Literal -height 15 /testbench/hc_lcd_data
add wave -noupdate -format Logic -height 15 /testbench/hc_grest
add wave -noupdate -format Logic -height 15 /testbench/hc_scen
add wave -noupdate -format Logic -height 15 /testbench/hc_sda
add wave -noupdate -format Logic -height 15 /testbench/hc_adc_penirq_n
add wave -noupdate -format Logic -height 15 /testbench/hc_adc_dout
add wave -noupdate -format Logic -height 15 /testbench/hc_adc_busy
add wave -noupdate -format Logic -height 15 /testbench/hc_adc_din
add wave -noupdate -format Logic -height 15 /testbench/hc_adc_dclk
add wave -noupdate -format Logic -height 15 /testbench/hc_adc_cs_n
add wave -noupdate -format Logic -height 15 /testbench/hc_i2c_sclk
add wave -noupdate -format Logic -height 15 /testbench/hc_i2c_sdat
add wave -noupdate -format Literal -height 15 /testbench/hc_td_d
add wave -noupdate -format Logic -height 15 /testbench/hc_td_hs
add wave -noupdate -format Logic -height 15 /testbench/hc_td_vs
add wave -noupdate -format Logic -height 15 /testbench/hc_td_27mhz
add wave -noupdate -format Logic -height 15 /testbench/hc_td_reset
add wave -noupdate -format Logic -height 15 /testbench/hc_aud_adclrck
add wave -noupdate -format Logic -height 15 /testbench/hc_aud_adcdat
add wave -noupdate -format Logic -height 15 /testbench/hc_aud_daclrck
add wave -noupdate -format Logic -height 15 /testbench/hc_aud_dacdat
add wave -noupdate -format Logic -height 15 /testbench/hc_aud_bclk
add wave -noupdate -format Logic -height 15 /testbench/hc_aud_xck
add wave -noupdate -format Logic -height 15 /testbench/hc_sd_dat
add wave -noupdate -format Logic -height 15 /testbench/hc_sd_dat3
add wave -noupdate -format Logic -height 15 /testbench/hc_sd_cmd
add wave -noupdate -format Logic -height 15 /testbench/hc_sd_clk
add wave -noupdate -format Literal -height 15 /testbench/hc_tx_d
add wave -noupdate -format Literal -height 15 /testbench/hc_rx_d
add wave -noupdate -format Logic -height 15 /testbench/hc_tx_clk
add wave -noupdate -format Logic -height 15 /testbench/hc_rx_clk
add wave -noupdate -format Logic -height 15 /testbench/hc_tx_en
add wave -noupdate -format Logic -height 15 /testbench/hc_rx_dv
add wave -noupdate -format Logic -height 15 /testbench/hc_rx_crs
add wave -noupdate -format Logic -height 15 /testbench/hc_rx_err
add wave -noupdate -format Logic -height 15 /testbench/hc_rx_col
add wave -noupdate -format Logic -height 15 /testbench/hc_mdio
add wave -noupdate -format Logic -height 15 /testbench/hc_mdc
add wave -noupdate -format Logic -height 15 /testbench/hc_eth_reset_n
add wave -noupdate -format Logic -height 15 /testbench/hc_uart_rxd
add wave -noupdate -format Logic -height 15 /testbench/hc_uart_txd
add wave -noupdate -format Logic -height 15 /testbench/hc_ps2_dat
add wave -noupdate -format Logic -height 15 /testbench/hc_ps2_clk
add wave -noupdate -format Literal -height 15 /testbench/hc_vga_data
add wave -noupdate -format Logic -height 15 /testbench/hc_vga_clock
add wave -noupdate -format Logic -height 15 /testbench/hc_vga_hs
add wave -noupdate -format Logic -height 15 /testbench/hc_vga_vs
add wave -noupdate -format Logic -height 15 /testbench/hc_vga_blank
add wave -noupdate -format Logic -height 15 /testbench/hc_vga_sync
add wave -noupdate -format Logic -height 15 /testbench/hc_id_i2cscl
add wave -noupdate -format Logic -height 15 /testbench/hc_id_i2cdat
add wave -noupdate -format Logic -height 15 /testbench/phy_tx_er
add wave -noupdate -format Logic -height 15 /testbench/phy_gtx_clk
add wave -noupdate -format Literal -height 15 /testbench/hc_tx_dt
add wave -noupdate -format Literal -height 15 /testbench/hc_rx_dt
add wave -noupdate -divider {CPU 1}
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/ici
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/ico
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/dci
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/dco
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/rfi
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/rfo
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/irqi
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/irqo
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/dbgi
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/dbgo
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/r
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/wpr
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/dsur
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/p0/iu0/ir
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/cmem0/crami
add wave -noupdate -format Literal -height 15 -radix hexadecimal /testbench/d3/l3/cpu__0/u0/cmem0/cramo
add wave -noupdate -divider AMBA
add wave -noupdate -format Literal -height 15 /testbench/d3/apbi
add wave -noupdate -format Literal -height 15 /testbench/d3/apbo
add wave -noupdate -format Literal -height 15 /testbench/d3/ahbsi
add wave -noupdate -format Literal -height 15 /testbench/d3/ahbso
add wave -noupdate -format Literal -height 15 /testbench/d3/ahbmi
add wave -noupdate -format Literal -height 15 /testbench/d3/ahbmo
add wave -noupdate -format Logic -height 15 /testbench/d3/clkm
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {119390198 ps} 0}
configure wave -namecolwidth 314
configure wave -valuecolwidth 136
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
WaveRestoreZoom {0 ps} {164673600 ps}
