LEON3 Template design for TerASIC Altera DE2-115 board
------------------------------------------------------

0. Introduction
---------------

The leon3 design can be synthesized with quartus or synplify,
and can reach 50 - 70 MHz depending on configuration and synthesis
options. Use 'make quartus' or 'make quartus-synp' to run the
complete flow. To program the FPGA in batch mode, use 
'make quartus-prog-fpga' or 'make quartus-prog-fpga-ref (reference config).
On linux, you might need to start jtagd as root to get the proper
port permissions. LEON3 reset is mapped on KEY0.

The output from grmon should look something like this:


  GRMON LEON debug monitor v3.1.1 64-bit professional version
  
  Copyright (C) 2019 Cobham Gaisler - All rights reserved.
  For latest updates, go to http://www.gaisler.com/
  Comments or bug-reports to support@gaisler.com

 Ethernet startup...
  GRLIB build version: 4243
  Detected frequency:  50.0 MHz
  
  Component                            Vendor
  LEON3 SPARC V8 Processor             Cobham Gaisler
  AHB Debug UART                       Cobham Gaisler
  JTAG Debug Link                      Cobham Gaisler
  GR Ethernet MAC                      Cobham Gaisler
  LEON2 Memory Controller              European Space Agency
  AHB/APB Bridge                       Cobham Gaisler
  LEON3 Debug Support Unit             Cobham Gaisler
  Generic UART                         Cobham Gaisler
  Multi-processor Interrupt Ctrl.      Cobham Gaisler
  Modular Timer Unit                   Cobham Gaisler
  General Purpose I/O port             Cobham Gaisler
  SPI Controller                       Cobham Gaisler
  GRDMAC DMA Controller                Cobham Gaisler
  AHB Status Register                  Cobham Gaisler
  
  Use command 'info sys' to print a detailed report of attached cores

grmon3> info sys
  cpu0      Cobham Gaisler  LEON3 SPARC V8 Processor    
            AHB Master 0
  ahbuart0  Cobham Gaisler  AHB Debug UART    
            AHB Master 1
            APB: 80000700 - 80000800
            Baudrate 115200, AHB frequency 50.00 MHz
  ahbjtag0  Cobham Gaisler  JTAG Debug Link    
            AHB Master 2
  greth0    Cobham Gaisler  GR Ethernet MAC    
            AHB Master 3
            APB: 80000E00 - 80000F00
            IRQ: 12
            edcl ip 192.168.111.2, buffer 2 kbyte
  mctrl0    European Space Agency  LEON2 Memory Controller    
            AHB: 00000000 - 20000000
            AHB: 40000000 - 80000000
            APB: 80000000 - 80000100
            8-bit prom @ 0x00000000
            32-bit sdram: 1 * 128 Mbyte @ 0x40000000
            col 10, cas 2, ref 7.8 us
  apbmst0   Cobham Gaisler  AHB/APB Bridge    
            AHB: 80000000 - 80100000
  dsu0      Cobham Gaisler  LEON3 Debug Support Unit    
            AHB: 90000000 - A0000000
            AHB trace: 1024 lines, 32-bit bus
            CPU0:  win 8, nwp 4, itrace 1024, V8 mul/div, srmmu, lddel 1
                   stack pointer 0x47fffff0
                   icache 4 * 4 kB, 32 B/line, lru
                   dcache 4 * 4 kB, 16 B/line, lru, snoop tags
  uart0     Cobham Gaisler  Generic UART    
            APB: 80000100 - 80000200
            IRQ: 2
            Baudrate 38343, FIFO debug mode available
  irqmp0    Cobham Gaisler  Multi-processor Interrupt Ctrl.    
            APB: 80000200 - 80000300
  gptimer0  Cobham Gaisler  Modular Timer Unit    
            APB: 80000300 - 80000400
            IRQ: 8
            16-bit scalar, 2 * 32-bit timers, divisor 50
  gpio0     Cobham Gaisler  General Purpose I/O port    
            APB: 80000900 - 80000A00
  spi0      Cobham Gaisler  SPI Controller    
            APB: 80000A00 - 80000B00
            IRQ: 10
            FIFO depth: 4, 1 slave select signals
            Maximum word length: 32 bits
            Supports 3-wire mode
            Controller index for use in GRMON: 0
  dma0      Cobham Gaisler  GRDMAC DMA Controller    
            APB: 80001000 - 80001100
            IRQ: 3
  ahbstat0  Cobham Gaisler  AHB Status Register    
            APB: 80000F00 - 80001000
            IRQ: 1


1. SDRAM interface

The SDRAM works fine with the MCTRL controller, providing 128 Mbyte memory.


2. FLASH

The FLASH is also interfaced with MCTRL, in 8-bit mode. Programming
works fine with GRMON.

grmon3> flash 
  
  AMD-style 8-bit flash

  Manuf.        : AMD               
  Device        : S29JL064J         
  
  1 x 8 Mbytes = 8 Mbytes total @ 0x00000000
  
  CFI information
  Flash family  : 2
  Flash size    : 64 Mbit
  Erase regions : 2
  Erase blocks  : 135
  Write buffer  : 32 bytes (limited to 32)
  Lock-down     : Not supported
  Region  0     : 8 blocks of 8 kB
  Region  1     : 127 blocks of 64 kB


3. UART

The single RS232 port can be use as console when switch SW0 is
off, or as debug link for GRMON when SW0 is on.


4. Ethernet

The Ethernet port 0 is supported in 10/100 Mbit MII mode. This requires
that the jumper JP1 is set to short pins 2-3, rather than the 1-2 as
is default. The Ethernet debug link (EDCL) is enabled and set to IP
192.168.0.51.


5. SPI

Two SPI cores can be enabled in the design. The signal map is as follows:

SPICTRL SPI master controller:
Design signal  SPI signal   JP5 pin
  gpio(35)       miso         40
  gpio(34)       mosi         39
  gpio(33)       sck          38
  gpio(32)      slv. sel.     37

SPI2AHB SPI to AHB bridge:
Design signal  SPI signal   JP5 pin
  gpio(31)       miso         36
  gpio(30)       mosi         35
  gpio(29)       sck          34
  gpio(28)      slv. sel.     33

The general purpose I/O port (GRGPIO) is enabled by default in the
design and maps gpio(0) to gpio(30). If SPI2AHB is enabled then the
number of GPIO lines must be decreased to 28.


6. Other functions

Not yet supported: PS/2, SSRAM, VGA, video grabber, USB, audio ...
