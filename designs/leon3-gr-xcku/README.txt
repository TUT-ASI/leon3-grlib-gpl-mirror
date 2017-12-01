This design is tailored to the COBHAM GAISLER Kintex-Ultrascale GR-XCKU board

Note: This design requires that the GRLIB_SIMULATOR variable is
correctly set. Please refer to the documentation in doc/grlib.pdf for
additional information.

Note: The Vivado flow and parts of this design are still
experimental. Currently the design configuration should be left as-is.

Note: You must have Vivado 2017.1 in your path for the make targets to work.

The XILINX_VIVADO variable must be exported correctly.

Ultrascale Specific 
-------------------
* New clock generator primitive MMCME3_ADV is added

* New Slew rate for pads is supported 

	* 0 = SLOW
	* 1 = FAST
	* 2 = MEDIUM

Design specifics
----------------

* Synthesis should be done using Vivado 2016.4 or newer.

* The xconfig utility can be used for configuration.

* The APB UART FIFO size needs to be 8 for the simulation to complete.

* The clock is generated from CLKGEN which uses MMCME3, and can be controlled via xconfig.
  The Vivado synthesis tool will map the clock generator to MMCME3 if other clock primitives are selected.

* 32-bit flash prom can be read at address 0. It can be programmed
  with GRMON version 2.0.30-74 or later.

* The application UART1 is connected to the RS232 connector and debug UART to DSU connector.

* The JTAG DSU interface is not supported for XCKU060 yet in GRMON. Use Debug UART by "grmon -UART /dev/ttyUSB1" 
  until support is provided.

* If one of the memory is to be disabled use -nosram/-nosdram during GRMON start.

Simulation and synthesis
------------------------

To simulate using XSIM and run systest.c on the Leon design using the memory 
controller from Xilinx use the make targets:

  make soft
  make vivado-launch

Run simulation from the GUI.

		To simulate using Modelsim/Aldec and run systest.c on the Leon design using 
		the memory controller from Xilinx use the make targets:
		 
		  make vsim
		  make soft
		  make vsim-launch
		
To simulate using Modelsim/Aldec and run systest.c on the Leon design using 
the memory controller from Xilinx use the make targets:

  make soft                    -- compiles software
  make map_xilinx_7series_lib
  make sim
  make sim-launch


To synthesize the design, do

  make vivado

* After successfully programmed the FPGA the user might have to press
  the 'Reset' button in order to successfully complete the programming.
  Led Error and led Prog should blink during programming and led Done will turn 
  Green after succesful programming.



Simulation options
------------------

All options are set either by editing the testbench or specify/modify the generic 
default value when launching the simulator. For Modelsim use the option "-g" i.e.
to enable processor disassembly to console launch modelsim with the option: "-gdisas=1"

disas - Enable processor disassembly to console


FPGA configuration
------------------
The FPGA is configured by 

	make vivado
	make vivado-prog-fpga
 
This will load the program to the Parallel flash.

--------------------------------------------

[root@ext-ba19e4 leon3-gr-xcku]# make vivado-prog-fpga
xmd

****** Xilinx Microprocessor Debugger (XMD) Engine
****** XMD v2016.4 (64-bit)
  **** SW Build 1756540 on Mon Jan 23 19:11:19 MST 2017
    ** Copyright 1986-2016 Xilinx, Inc. All Rights Reserved.

WARNING: XMD has been deprecated and will be removed in future.
         XSDB replaces XMD and provides additional functionality.
         We recommend you switch to XSDB for commandline debugging.
         Please refer to SDK help for more details.

XMD% 
Configuring Device 1 (xcku060) with Bitstream -- ./vivado/leon3-gr-xcku/leon3-gr-xcku.runs/impl_1/leon3mp.bit
....................................10....................................20
....................................30....................................40
....................................50...................................60
....................................70....................................80
....................................90....................................
Successfully downloaded bit file.

JTAG chain configuration
--------------------------------------------------
Device   ID Code        IR Length    Part Name
 1       13919093           6        xcku060


Selecting External QSPI FLASH
------------------------

The XCKU ref design supports Quad SPI flash and can be programmed by Vivado Indirect programming method.
The QSPI flash is tested with binary file with Bit swapping disabled.

Quad SPI flash is only supported by grmon2-2.0.56 or later

                 GRMON
                 -----
---------------------------------------------------------------------------------
--JTAG support is not yet available in GPL version. Use Uart instead
--Start grmon with -nosdram or -nosram commands if one of them need to be disabled. 
--Otherwise disable SDRAM from xconfig
---------------------------------------------------------------------------------- 

Output from GRMON
------------------

[root@ext-ba19e4 leon3-gr-xcku]# grmon -uart /dev/ttyUSB0 -u 

  GRMON2 LEON debug monitor v2.0.85 64-bit eval version
  
  Copyright (C) 2017 Cobham Gaisler - All rights reserved.
  For latest updates, go to http://www.gaisler.com/
  Comments or bug-reports to support@gaisler.com
  
  This eval version will expire on 14/12/2017

  using port /dev/ttyUSB0 @ 115200 baud
  Device ID:           0xA705
  GRLIB build version: 4194
  Detected frequency:  50 MHz
  
  Component                            Vendor
  LEON3 SPARC V8 Processor             Cobham Gaisler
  AHB Debug UART                       Cobham Gaisler
  JTAG Debug Link                      Cobham Gaisler
  LEON2 Memory Controller              European Space Agency
  AHB/APB Bridge                       Cobham Gaisler
  LEON3 Debug Support Unit             Cobham Gaisler
  Generic UART                         Cobham Gaisler
  Multi-processor Interrupt Ctrl.      Cobham Gaisler
  Modular Timer Unit                   Cobham Gaisler
  General Purpose I/O port             Cobham Gaisler
  
  Use command 'info sys' to print a detailed report of attached cores

grmon2> info sys
  cpu0      Cobham Gaisler  LEON3 SPARC V8 Processor    
            AHB Master 0
  ahbuart0  Cobham Gaisler  AHB Debug UART    
            AHB Master 1
            APB: 80000700 - 80000800
            Baudrate 115200, AHB frequency 50.00 MHz
  ahbjtag0  Cobham Gaisler  JTAG Debug Link    
            AHB Master 2
  mctrl0    European Space Agency  LEON2 Memory Controller    
            AHB: 00000000 - 20000000
            AHB: 40000000 - 80000000
            APB: 80000000 - 80000100
            32-bit prom @ 0x00000000
            32-bit static ram: 1 * 16384 kbyte @ 0x40000000
            32-bit sdram: 1 * 128 Mbyte @ 0x60000000
            col 10, cas 2, ref 7.8 us
  apbmst0   Cobham Gaisler  AHB/APB Bridge    
            AHB: 80000000 - 80100000
  dsu0      Cobham Gaisler  LEON3 Debug Support Unit    
            AHB: D0000000 - E0000000
            AHB trace: 256 lines, 32-bit bus
            CPU0:  win 8, hwbp 2, itrace 256, V8 mul/div, srmmu, lddel 1
                   stack pointer 0x40fffff0
                   icache 4 * 4 kB, 32 B/line, lru
                   dcache 4 * 4 kB, 32 B/line, lru, snoop tags
  uart0     Cobham Gaisler  Generic UART    
            APB: 80000100 - 80000200
            IRQ: 2
            Baudrate 38580, FIFO debug mode
  irqmp0    Cobham Gaisler  Multi-processor Interrupt Ctrl.    
            APB: 80000200 - 80000300
  gptimer0  Cobham Gaisler  Modular Timer Unit    
            APB: 80000300 - 80000400
            IRQ: 8
            8-bit scalar, 2 * 32-bit timers, divisor 25
  gpio0     Cobham Gaisler  General Purpose I/O port    
            APB: 80000A00 - 80000B00


---------------------------------Verify PROM(Parallel Flash)-------------------------
grmon2> flash
  
  AMD-style 32-bit (2x16-bit) flash

  Manuf.        : SST               SST               
  Device        : Unknown (0x536b)  Unknown (0x536b)  
  
  2 x 8 Mbytes = 16 Mbytes total @ 0x00000000
  
  CFI information
  Flash family  : 2
  Flash size    : 64 Mbit
  Erase regions : 2
  Erase blocks  : 1152
  Write buffer  : 32 bytes (limited to 32)
  Lock-down     : Not supported
  Region  0     : 1024 blocks of 2x64 kB
  Region  1     : 128 blocks of 2x64 kB

--------------------------------------------------------------------------------------
  Linux commands to generate 16MB and 128 MB random files for memory test.

dd if=/dev/urandom of=sample16M.txt bs=16M count=1	// SRAM verification
dd if=/dev/urandom of=sample128M.txt bs=128M count=1	// SDRAM verification	
---------------------------------------------------------------------------------------

---------------Verify SRAM---------------------


grmon2> load sample.txt 0x40000000
  40000000 Binary data               16.0MB /  16.0MB   [===============>] 100%
  Total size: 16.00MB (90.62kbit/s)
  Entry point 0x40000000
  Image $GRLIB/designs/leon3-gr-xcku/sample.txt loaded
  
grmon2> verify sample.txt 0x40000000
  40000000 Binary data               16.0MB /  16.0MB   [===============>] 100%
  Total size: 16.00MB (90.51kbit/s)
  Entry point 0x40000000
  Image of $GRLIB/designs/leon3-gr-xcku/sample.txt verified without errors

----------------Verify SDRAM-----------------

grmon2> load sample128M.txt 0x60000000
  60000000 Binary data              128.0MB / 128.0MB   [===============>] 100%
  Total size: 128.00MB (90.60kbit/s)
  Entry point 0x60000000
  Image $GRLIB/designs/leon3-gr-xcku/sample128M.txt loaded
  
grmon2> verify sample128M.txt 0x60000000
  60000000 Binary data              128.0MB / 128.0MB   [===============>] 100%
  Total size: 128.00MB (90.51kbit/s)
  Entry point 0x60000000
  Image of $GRLIB/designs/leon3-gr-xcku/sample128M.txt verified without errors





