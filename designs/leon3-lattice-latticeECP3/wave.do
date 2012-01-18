onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /testbench/clk
add wave -noupdate /testbench/errorn
add wave -noupdate -radix hexadecimal /testbench/address
add wave -noupdate -radix hexadecimal /testbench/data
add wave -noupdate /testbench/ramsn
add wave -noupdate /testbench/oen
add wave -noupdate /testbench/writen
add wave -noupdate /testbench/dsuen
add wave -noupdate /testbench/dsubre
add wave -noupdate -divider eth
add wave -noupdate /testbench/eth_rstn
add wave -noupdate /testbench/etx_clk
add wave -noupdate /testbench/erx_clk
add wave -noupdate -radix hexadecimal /testbench/erxdt
add wave -noupdate /testbench/erx_dv
add wave -noupdate /testbench/erx_er
add wave -noupdate /testbench/erx_col
add wave -noupdate /testbench/erx_crs
add wave -noupdate -radix hexadecimal /testbench/etxdt
add wave -noupdate /testbench/etx_en
add wave -noupdate /testbench/etx_er
add wave -noupdate /testbench/emdc
add wave -noupdate /testbench/emdio
add wave -noupdate /testbench/egtx_clk
add wave -noupdate /testbench/eth_clk125
add wave -noupdate /testbench/led
add wave -noupdate -childformat {{/testbench/DUT/eth1/e1/ethi.rxd -radix hexadecimal}} -subitemconfig {/testbench/DUT/eth1/e1/ethi.rxd {-height 16 -radix hexadecimal}} /testbench/DUT/eth1/e1/ethi
add wave -noupdate /testbench/DUT/eth1/e1/etho
add wave -noupdate -radix hexadecimal -childformat {{/testbench/DUT/eth1/e1/ahbmi.hgrant -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmi.hready -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmi.hresp -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmi.hrdata -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmi.hcache -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmi.hirq -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmi.testen -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmi.testrst -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmi.scanen -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmi.testoen -radix hexadecimal}} -subitemconfig {/testbench/DUT/eth1/e1/ahbmi.hgrant {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmi.hready {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmi.hresp {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmi.hrdata {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmi.hcache {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmi.hirq {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmi.testen {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmi.testrst {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmi.scanen {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmi.testoen {-height 16 -radix hexadecimal}} /testbench/DUT/eth1/e1/ahbmi
add wave -noupdate -radix hexadecimal -childformat {{/testbench/DUT/eth1/e1/ahbmo.hbusreq -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmo.hlock -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmo.htrans -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmo.haddr -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmo.hwrite -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmo.hsize -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmo.hburst -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmo.hprot -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmo.hwdata -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmo.hirq -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmo.hconfig -radix hexadecimal} {/testbench/DUT/eth1/e1/ahbmo.hindex -radix hexadecimal}} -subitemconfig {/testbench/DUT/eth1/e1/ahbmo.hbusreq {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmo.hlock {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmo.htrans {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmo.haddr {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmo.hwrite {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmo.hsize {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmo.hburst {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmo.hprot {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmo.hwdata {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmo.hirq {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmo.hconfig {-height 16 -radix hexadecimal} /testbench/DUT/eth1/e1/ahbmo.hindex {-height 16 -radix hexadecimal}} /testbench/DUT/eth1/e1/ahbmo
add wave -noupdate -divider {New Divider}
add wave -noupdate -radix hexadecimal /testbench/sram0(1)/sr0/d
add wave -noupdate -radix hexadecimal /testbench/sram0(1)/sr0/sr0/d
add wave -noupdate -radix hexadecimal /testbench/sram0(1)/sr0/sr1/d
add wave -noupdate -divider {New Divider}
add wave -noupdate -radix hexadecimal /testbench/sram0(0)/sr0/d
add wave -noupdate -radix hexadecimal /testbench/sram0(0)/sr0/sr0/d
add wave -noupdate -radix hexadecimal /testbench/sram0(0)/sr0/sr1/d
add wave -noupdate -divider {CPU 1}
add wave -noupdate -radix hexadecimal -childformat {{/testbench/DUT/apbi.psel -radix hexadecimal} {/testbench/DUT/apbi.penable -radix hexadecimal} {/testbench/DUT/apbi.paddr -radix hexadecimal} {/testbench/DUT/apbi.pwrite -radix hexadecimal} {/testbench/DUT/apbi.pwdata -radix hexadecimal} {/testbench/DUT/apbi.pirq -radix hexadecimal} {/testbench/DUT/apbi.testen -radix hexadecimal} {/testbench/DUT/apbi.testrst -radix hexadecimal} {/testbench/DUT/apbi.scanen -radix hexadecimal} {/testbench/DUT/apbi.testoen -radix hexadecimal}} -subitemconfig {/testbench/DUT/apbi.psel {-height 16 -radix hexadecimal} /testbench/DUT/apbi.penable {-height 16 -radix hexadecimal} /testbench/DUT/apbi.paddr {-height 16 -radix hexadecimal} /testbench/DUT/apbi.pwrite {-height 16 -radix hexadecimal} /testbench/DUT/apbi.pwdata {-height 16 -radix hexadecimal} /testbench/DUT/apbi.pirq {-height 16 -radix hexadecimal} /testbench/DUT/apbi.testen {-height 16 -radix hexadecimal} /testbench/DUT/apbi.testrst {-height 16 -radix hexadecimal} /testbench/DUT/apbi.scanen {-height 16 -radix hexadecimal} /testbench/DUT/apbi.testoen {-height 16 -radix hexadecimal}} /testbench/DUT/apbi
add wave -noupdate -radix hexadecimal /testbench/DUT/apbo
add wave -noupdate -radix hexadecimal -childformat {{/testbench/DUT/ahbsi.hsel -radix hexadecimal} {/testbench/DUT/ahbsi.haddr -radix hexadecimal} {/testbench/DUT/ahbsi.hwrite -radix hexadecimal} {/testbench/DUT/ahbsi.htrans -radix hexadecimal} {/testbench/DUT/ahbsi.hsize -radix hexadecimal} {/testbench/DUT/ahbsi.hburst -radix hexadecimal} {/testbench/DUT/ahbsi.hwdata -radix hexadecimal} {/testbench/DUT/ahbsi.hprot -radix hexadecimal} {/testbench/DUT/ahbsi.hready -radix hexadecimal} {/testbench/DUT/ahbsi.hmaster -radix hexadecimal} {/testbench/DUT/ahbsi.hmastlock -radix hexadecimal} {/testbench/DUT/ahbsi.hmbsel -radix hexadecimal} {/testbench/DUT/ahbsi.hcache -radix hexadecimal} {/testbench/DUT/ahbsi.hirq -radix hexadecimal} {/testbench/DUT/ahbsi.testen -radix hexadecimal} {/testbench/DUT/ahbsi.testrst -radix hexadecimal} {/testbench/DUT/ahbsi.scanen -radix hexadecimal} {/testbench/DUT/ahbsi.testoen -radix hexadecimal}} -subitemconfig {/testbench/DUT/ahbsi.hsel {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.haddr {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.hwrite {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.htrans {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.hsize {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.hburst {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.hwdata {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.hprot {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.hready {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.hmaster {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.hmastlock {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.hmbsel {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.hcache {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.hirq {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.testen {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.testrst {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.scanen {-height 16 -radix hexadecimal} /testbench/DUT/ahbsi.testoen {-height 16 -radix hexadecimal}} /testbench/DUT/ahbsi
add wave -noupdate -radix hexadecimal /testbench/DUT/ahbso
add wave -noupdate -radix hexadecimal /testbench/DUT/ahbmi
add wave -noupdate -radix hexadecimal /testbench/DUT/ahbmo
add wave -noupdate -radix hexadecimal -childformat {{/testbench/DUT/test0/r.hwrite -radix hexadecimal} {/testbench/DUT/test0/r.hsel -radix hexadecimal} {/testbench/DUT/test0/r.haddr -radix hexadecimal} {/testbench/DUT/test0/r.htrans -radix hexadecimal}} -subitemconfig {/testbench/DUT/test0/r.hwrite {-height 16 -radix hexadecimal} /testbench/DUT/test0/r.hsel {-height 16 -radix hexadecimal} /testbench/DUT/test0/r.haddr {-height 16 -radix hexadecimal} /testbench/DUT/test0/r.htrans {-height 16 -radix hexadecimal}} /testbench/DUT/test0/r
add wave -noupdate -radix hexadecimal -childformat {{/testbench/DUT/irqctrl/irqctrl0/r.imask -radix hexadecimal} {/testbench/DUT/irqctrl/irqctrl0/r.ilevel -radix hexadecimal} {/testbench/DUT/irqctrl/irqctrl0/r.ipend -radix hexadecimal} {/testbench/DUT/irqctrl/irqctrl0/r.iforce -radix hexadecimal} {/testbench/DUT/irqctrl/irqctrl0/r.ibroadcast -radix hexadecimal} {/testbench/DUT/irqctrl/irqctrl0/r.irl -radix hexadecimal} {/testbench/DUT/irqctrl/irqctrl0/r.cpurst -radix hexadecimal}} -subitemconfig {/testbench/DUT/irqctrl/irqctrl0/r.imask {-height 16 -radix hexadecimal} /testbench/DUT/irqctrl/irqctrl0/r.ilevel {-height 16 -radix hexadecimal} /testbench/DUT/irqctrl/irqctrl0/r.ipend {-height 16 -radix hexadecimal} /testbench/DUT/irqctrl/irqctrl0/r.iforce {-height 16 -radix hexadecimal} /testbench/DUT/irqctrl/irqctrl0/r.ibroadcast {-height 16 -radix hexadecimal} /testbench/DUT/irqctrl/irqctrl0/r.irl {-height 16 -radix hexadecimal} /testbench/DUT/irqctrl/irqctrl0/r.cpurst {-height 16 -radix hexadecimal}} /testbench/DUT/irqctrl/irqctrl0/r
add wave -noupdate -radix hexadecimal -childformat {{/testbench/DUT/irqctrl/irqctrl0/irqi(0) -radix hexadecimal}} -subitemconfig {/testbench/DUT/irqctrl/irqctrl0/irqi(0) {-height 16 -radix hexadecimal}} /testbench/DUT/irqctrl/irqctrl0/irqi
add wave -noupdate -radix hexadecimal -childformat {{/testbench/DUT/irqctrl/irqctrl0/irqo(0) -radix hexadecimal}} -subitemconfig {/testbench/DUT/irqctrl/irqctrl0/irqo(0) {-height 16 -radix hexadecimal}} /testbench/DUT/irqctrl/irqctrl0/irqo
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1222798611 ps} 0}
configure wave -namecolwidth 205
configure wave -valuecolwidth 146
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
configure wave -timelineunits ns
update
WaveRestoreZoom {1222817786 ps} {1222935690 ps}
