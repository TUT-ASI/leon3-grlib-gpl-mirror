Overview
--------

Note: This design is EXPERIMENTAL.

This LEON3 design is tailored for the Altera Cyclone V SX SoC on the
Terasic Sockit board synthesizable with Quartus II 14.1

Design contains:
  * LEON3 running at 70 MHz
  * 1 GiB DDR3 running at 300 MHz using Quartus soft memory controller IP
  * FPGA2HPS bridge allowing the LEON3 system to access the hard processor
    address space.
  * HPS2FPGA bridge allowing the hard processor system to access the LEON3
    address space.
  * JTAG debug link connected to on-board USB blaster II

Information about the hard processor system can be found in:
https://www.altera.com/en_US/pdfs/literature/hb/cyclone-v/cv_5v4.pdf

Important notes
---------------

* The HPS part of the system requires ARM-processor to be booted. If
  the HPS system is not booted, the bridges will not work.

* The access to the HPS peripherals is given an offset in the AHB2AXI 
  bridge (example: 0xCF700000 translates to 0xFF700000). This can be 
  changed by the user.

* This template was designed with using the Linux image delivered
  with the board in mind. 

* The JTAG debug link requires a system clock frequency several times
  higher than the JTAG clock to function properly. To reduce the
  chance of any synchronization errors it is possible to lower the
  altera JTAG clock frequency by using the command:

	jtagconfig --setparam <cable number> JtagClock <clock freq>
	
  Avaiable options for clock freq are 6M, 16M and 24M where 24M is
  the default value. If you unplug the USB Blaster II cable the value
  will be reset to 24M. For this board, cable number can be set to
  "CV SoCKit", including the "".
  
* Note that there is an issue with Quartus II 14.1 running on Ubuntu 14.04.
  It is a library issue that causes the automatic tcl scipts for pin
  assignments to fail. To bypass this issue, comment out the field QSF_NEXT
  in the Makefile and POST_MODULE_SCRIPT_FILE in qsf_append.qsf. Then run
  the implementation in the Quartus II gui by running "make quartus-launch".
  Run the "Analysis & Synthesis" step in Quartus, then run the pin assignment
  tcl scipts for the HPS and the DDR3 manually before running the full
  implementation.

Design details
--------------

LED assignments:
  LED3 - CPU in error mode
  LED2 - DSU active
  LED1 - unused
  LED0 - unused

Push button assignments:
  KEY4 "FPGA RESET" - Reset LEON system

DIP switches (SW3):
  3 - unused
  2 - unused
  1 - unused
  0 - unused

Interrupts:
  7 - APB UART
  8 - Timer

-----------
Simulation
-----------
The standard GRLIB flow with "make vsim" and then "vsim testbench" can be used to
simulate the design. The simulation uses a simplified DDR3 controller.

-----------
Programming
-----------
To synthesize the design (requires Quartus II 14.1), first build the megafunctions 
using "make qwiz", then use the "make quartus" command to synthesize. To synthesize
in the Quartus II gui use "make quartus-launch".

Use "make quartus-prog-fpga" to program the FPGA. Make sure that the JTAG CHAIN SW
on the board is set to "00", otherwise the programming will fail.

-----------
Debugging
-----------
Debugging can be done over the same interface using "grmon -altjtag".

user@computer ~ $ jtagconfig --setparam "CV SoCKit" JtagClock 6M
user@computer ~ $ grmon -altjtag -u -nb

  GRMON2 LEON debug monitor v2.0.63 eval version
  
  Copyright (C) 2015 Cobham Gaisler - All rights reserved.
  For latest updates, go to http://www.gaisler.com/
  Comments or bug-reports to support@gaisler.com
  
  This eval version will expire on 10/10/2015

 JTAG chain (1): 5CSEBA6(.|ES)/5CSEMA6/.. 
  GRLIB build version: 4155
  Detected frequency:  70 MHz
  
  Component                            Vendor
  LEON3 SPARC V8 Processor             Cobham Gaisler
  JTAG Debug Link                      Cobham Gaisler
  Unknown device                       Cobham Gaisler
  Generic AHB ROM                      Cobham Gaisler
  AHB/APB Bridge                       Cobham Gaisler
  LEON3 Debug Support Unit             Cobham Gaisler
  Avalon-MM memory controller          Cobham Gaisler
  Unknown device                       Cobham Gaisler
  Generic UART                         Cobham Gaisler
  Multi-processor Interrupt Ctrl.      Cobham Gaisler
  Modular Timer Unit                   Cobham Gaisler
  
  Use command 'info sys' to print a detailed report of attached cores

grmon2> info sys
  cpu0      Cobham Gaisler  LEON3 SPARC V8 Processor    
            AHB Master 0
  ahbjtag0  Cobham Gaisler  JTAG Debug Link    
            AHB Master 1
  adev2     Cobham Gaisler  Unknown device    
            AHB Master 2
  adev3     Cobham Gaisler  Generic AHB ROM    
            AHB: 00000000 - 00100000
  apbmst0   Cobham Gaisler  AHB/APB Bridge    
            AHB: 80000000 - 80100000
  dsu0      Cobham Gaisler  LEON3 Debug Support Unit    
            AHB: D0000000 - E0000000
            AHB trace: 64 lines, 32-bit bus
            CPU0:  win 8, hwbp 2, itrace 64, V8 mul/div, srmmu, lddel 1
                   stack pointer 0x7ffffff0
                   icache 2 * 4 kB, 32 B/line 
                   dcache 2 * 4 kB, 32 B/line , snoop tags
  ahb2avla0 Cobham Gaisler  Avalon-MM memory controller    
            AHB: 40000000 - 80000000
            AHB: FFF00000 - 00000000
            SDRAM: 1024 Mbyte
  adev7     Cobham Gaisler  Unknown device    
            AHB: CF000000 - D0000000
  uart0     Cobham Gaisler  Generic UART    
            APB: 80000100 - 80000200
            IRQ: 2
            Baudrate 38377, FIFO debug mode
  irqmp0    Cobham Gaisler  Multi-processor Interrupt Ctrl.    
            APB: 80000200 - 80000300
  gptimer0  Cobham Gaisler  Modular Timer Unit    
            APB: 80000300 - 80000400
            IRQ: 8
            8-bit scalar, 2 * 32-bit timers, divisor 70

grmon2> load ~/dhry.exe; verify ~/dhry.exe; run
  40000000 .text                     56.8kB /  56.8kB   [===============>] 100%
  4000E330 .data                      2.7kB /   2.7kB   [===============>] 100%
  Total size: 59.50kB (2.75Mbit/s)
  Entry point 0x40000000
  Image ~/dhry.exe loaded
  40000000 .text                     56.8kB /  56.8kB   [===============>] 100%
  4000E330 .data                      2.7kB /   2.7kB   [===============>] 100%
  Total size: 59.50kB (107.74kbit/s)
  Entry point 0x40000000
  Image of ~/dhry.exe verified without errors
Execution starts, 400000 runs through Dhrystone
Microseconds for one run through Dhrystone:    6.4 
Dhrystones per Second:                      156862.8 

Dhrystones MIPS      :                        89.3 

  
  Program exited normally.
	




