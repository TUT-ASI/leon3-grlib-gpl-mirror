setMode -bs
setCable -port auto
Identify 
assignFile -p 1 -file "xilinx-sp601-xc6slx16.mcs"
setAttribute -position 1 -attr packageName -value "(null)"
Program -p 1 -v -defaultVersion 0 
quit
