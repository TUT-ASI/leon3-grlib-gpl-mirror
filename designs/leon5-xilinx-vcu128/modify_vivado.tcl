append vc "import_ip -files vivado/axi_dw_conv.xci -name axi_dw_conv "
append vc "\ngenerate_target  all \[get_files ./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.srcs/sources_1/ip/axi_dw_conv/axi_dw_conv.xci\] -force "
set f [open ./vivado/leon5mp_vivado.tcl a]
puts $f $vc
close $f
return


	
