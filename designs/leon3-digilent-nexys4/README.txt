This leon3 design is tailored to the Digilent Nexys4 board


Simulation and synthesis
------------------------

The design currently supports synthesis though with xilinx ise and synplify.
Make scripts do not work for vivado.
 
Compile Modelsim simulation: make vsim
Synthesise with Xilinx ISE:  make ise
Program the FPGA:            make ise-prog-fpga
Program the PROM             make ise-prog-prom

Connecting to USB-UART
----------------------
The USB/JTAG and USB/UART shares the same port and can cause problems.

If the output from the dmsg includes the output below, it is possible that
it is caused by a linux driver incompaiblity. 

Dmesg output: ftdi_sio ttyUSB0: FTDI USB Serial Device converter 
              now disconnected from ttyUSB<#>

Procedure:
 * Power the board with a power supply
 * (Program the board over JTAG)
 * rmmod the ftdi drivers
     sudo rmmod ftdi_sio
     sudo rmmod usbserial 
 * Replug the micro-USB cable. The /dev/ttyUSB0  and/or /dev/ttyUSB1 
   should now exist. (JTAG over USB is temporarily lost)
 * Run GRMON: grmon -uart /dev/ttyUSB1 -u
 * Reconnecting the micro-USB cable migth load back the ftdi_sio and usbserial
   drivers. Thefore the procedure might have to be repeated.

RECOMENDED SOLUTION use other pins for UART and not over USB/UART.

Design specifics
----------------

* In order to connect through the USB JTAG-interface run "grmon -digilent".
  It is also possible to connect through ethernet. "grmon -eth <ip addr>"

* System reset is mapped to the CPU RESET button

* LED 0/1 indicate USB-UART RX/TX activity. (Connected to Debug UART)

* LED 2 DSU Debug Mode

* LED 3 indicate processor in error mode

* The SRAM is accessed asynchronously and has an accestime of 70ns. It is therefore
  necesssssary to add extra wait states for the SRAM. This can be done by starting 
  GRMON with the parameters: -ramrws 3  -ramwws 3
  One or two waitstates might also work.

* The design has no flash/ROM. An AHBROM is therefore instatiated.
  Curently there is no SPI or SDcard support.

* The application UART1 is unconnected. To enable it uncomment the in/out
  pads for the apbuart and comment out the ahbuart pads.

* The JTAG DSU interface is enabled and accesible via the USB/JTAG port and USB/UART.
  Start grmon with -digilent to connect with USB/JTAG.
  
* Output from GRMON is:

grmon -eth 192.168.0.51 -u
  
  GRMON2 LEON debug monitor v2
  
  Copyright (C) 2013 Aeroflex Gaisler - All rights reserved.
  For latest updates, go to http://www.gaisler.com/
  Comments or bug-reports to support@gaisler.com
  
Parsing -eth 192.168.0.51
Parsing -u

Commands missing help:
 datacache

 Ethernet startup...
  GRLIB build version: 4137
  Detected frequency:  50 MHz
  
  Component                            Vendor
  LEON3 SPARC V8 Processor             Aeroflex Gaisler
  AHB Debug UART                       Aeroflex Gaisler
  JTAG Debug Link                      Aeroflex Gaisler
  GR Ethernet MAC                      Aeroflex Gaisler
  AHB/APB Bridge                       Aeroflex Gaisler
  LEON3 Debug Support Unit             Aeroflex Gaisler
  LEON2 Memory Controller              European Space Agency
  Generic AHB ROM                      Aeroflex Gaisler
  Generic UART                         Aeroflex Gaisler
  Multi-processor Interrupt Ctrl.      Aeroflex Gaisler
  Modular Timer Unit                   Aeroflex Gaisler
  
  Use command 'info sys' to print a detailed report of attached cores

grmon2> load ~/dhry.leon3
  40000000 .text                     54.7kB /  54.7kB   [===============>] 100%
  4000DAF0 .data                      2.7kB /   2.7kB   [===============>] 100%
  Total size: 57.44kB (39.21Mbit/s)
  Entry point 0x40000000
  Image /home/alexander/dhry.leon3 loaded
  
grmon2> run
Execution starts, 1000000 runs through Dhrystone
Total execution time:                         11.0 s
Microseconds for one run through Dhrystone:   11.0 
Dhrystones per Second:                      91123.5 

Dhrystones MIPS      :                        51.9 


  Program exited normally.
  
grmon2> info sys
  cpu0      Aeroflex Gaisler  LEON3 SPARC V8 Processor    
            AHB Master 0
  ahbuart0  Aeroflex Gaisler  AHB Debug UART    
            AHB Master 1
            APB: 80000700 - 80000800
            Baudrate 115200, AHB frequency 50.00 MHz
  ahbjtag0  Aeroflex Gaisler  JTAG Debug Link    
            AHB Master 2
  greth0    Aeroflex Gaisler  GR Ethernet MAC    
            AHB Master 3
            APB: 80000F00 - 80001000
            IRQ: 12
            edcl ip 192.168.0.51, buffer 2 kbyte
  apbmst0   Aeroflex Gaisler  AHB/APB Bridge    
            AHB: 80000000 - 80100000
  dsu0      Aeroflex Gaisler  LEON3 Debug Support Unit    
            AHB: 90000000 - A0000000
            AHB trace: 128 lines, 32-bit bus
            CPU0:  win 8, hwbp 2, itrace 128, V8 mul/div, lddel 1
                   stack pointer 0x40fffff0
                   icache 2 * 8 kB, 16 B/line lru
                   dcache 2 * 4 kB, 16 B/line lru
  mctrl0    European Space Agency  LEON2 Memory Controller    
            APB: 80000000 - 80000100
            16-bit static ram: 1 * 16384 kbyte @ 0x40000000
  adev7     Aeroflex Gaisler  Generic AHB ROM    
            AHB: 00000000 - 00100000
  uart0     Aeroflex Gaisler  Generic UART    
            APB: 80000100 - 80000200
            IRQ: 2
            Baudrate 38343
  irqmp0    Aeroflex Gaisler  Multi-processor Interrupt Ctrl.    
            APB: 80000200 - 80000300
  gptimer0  Aeroflex Gaisler  Modular Timer Unit    
            APB: 80000300 - 80000400
            IRQ: 8
            8-bit scalar, 2 * 32-bit timers, divisor 50
