setMode -bs
setCable -port auto
Identify 
identifyMPM 
assignFile -p 1 -file "xilinx-sp601-xc6slx16.bit"
Program -p 1 -v -defaultVersion 0 
quit
