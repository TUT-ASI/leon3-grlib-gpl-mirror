
This leon3 design is tailored to the LatticeECP3 Versa Evaluation Board
-----------------------------------------------------------------------

Design specifics:

* System reset is mapped to the FPGA GSRN button

* FTDI High-Speed USB IC contains UART interface where AHB DSU UART is 
  connected (I/O pins G19, G20).

* Additional UART, the console UART (APB UART 1), is available on 
  x3 Expansion Connector - pins 6, 7.

* The GRETH core (connected to PHY#2 interface) is enabled and runs without 
  problems at 100 Mbit.   Using 1 Gbit is also possible with the commercial 
  grlib version. Ethernet debug link (EDCL) is enabled, 
  default IP is 192.168.0.133.

* Design contains memory controller instantiation for connecting to 
  simulation model of generic 16-bit async SRAM. This helps to simulate the design.

* The JTAG DSU interface is not available - JTAG TAP controller is under development.

* DDR3 support is under development.

* PCI Express x1 support is under development.

* The LEON3 processor can run up to 65 - 80 MHz on the board in the typical 
  configuration.

* LEDs on the board are configured as follows:
	led(0) <= not cgo.clklock;
	led(1) <= not cgo1.clklock;
	led(2) <= errorn_s;
	led(4) <= not dsuo.active;
	led(5) <= not gpto.wdog;
	led(6) <= not dui.rxd; (possibly not uart1i.rxd or not etho.tx_en)
	led(7) <= not duo.txd; (possibly not uart1o.txd or not etho.tx_er)


* Sample output from GRMON is:

 GRMON2 LEON debug monitor v2.0.24b internal version
  
  Copyright (C) 2012 Aeroflex Gaisler - All rights reserved.
  For latest updates, go to http://www.gaisler.com/
  Comments or bug-reports to support@gaisler.com
  

Parsing -eth 192.168.0.133
 ethernet startup

Commands missing help:

  GRLIB build version: 4113
  Detected frequency:  100 MHz
  
  Component                            Vendor
  LEON3 SPARC V8 Processor             Aeroflex Gaisler
  AHB Debug UART                       Aeroflex Gaisler
  GR Ethernet MAC                      Aeroflex Gaisler
  LEON2 Memory Controller              European Space Agency
  AHB/APB Bridge                       Aeroflex Gaisler
  LEON3 Debug Support Unit             Aeroflex Gaisler
  Single-port AHB SRAM module          Aeroflex Gaisler
  Generic AHB ROM                      Aeroflex Gaisler
  Generic UART                         Aeroflex Gaisler
  Multi-processor Interrupt Ctrl.      Aeroflex Gaisler
  Modular Timer Unit                   Aeroflex Gaisler
  
  Use command 'info sys' to print a detailed report of attached cores


grmon2> info sys
  cpu0      Aeroflex Gaisler  LEON3 SPARC V8 Processor    
            AHB Master 0
  ahbuart0  Aeroflex Gaisler  AHB Debug UART    
            AHB Master 1
            APB: 80000700 - 80000800
            Baudrate 115200, AHB frequency 100000000.00
  greth0    Aeroflex Gaisler  GR Ethernet MAC    
            AHB Master 2
            APB: 80000F00 - 80001000
            IRQ: 12
            edcl ip 192.168.0.133, buffer 4 kbyte
  mctrl0    European Space Agency  LEON2 Memory Controller    
            APB: 80000000 - 80000100
  apbmst0   Aeroflex Gaisler  AHB/APB Bridge    
            AHB: 80000000 - 80100000
  dsu0      Aeroflex Gaisler  LEON3 Debug Support Unit    
            AHB: 90000000 - A0000000
            AHB trace: 256 lines, 32-bit bus
            CPU0:  win 8, hwbp 2, itrace 256, V8 mul/div, srmmu, lddel 1
                   stack pointer 0xa0000ff0
                   icache 2 * 8 kB, 32 B/line lru
                   dcache 2 * 4 kB, 16 B/line lru
  ahbram0   Aeroflex Gaisler  Single-port AHB SRAM module    
            AHB: A0000000 - A0100000
            32-bit static ram: 4 kB @ 0xa0000000
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
            8-bit scalar, 2 * 32-bit timers, divisor 100
  
grmon2> 


