This design is tailored to the Cobham GR-CPCI-XC7K board

Note: This design requires that the GRLIB_SIMULATOR variable is
correctly set. Please refer to the documentation in doc/grlib.pdf for
additional information.

Note: The Vivado flow and parts of this design are still
experimental. Currently the design configuration should be left as-is.

Note: You must have Vivado 2017.1 in your path for the make targets to work.

The XILINX_VIVADO variable must be exported for the mig_7series target
to work correctly: export XILINX_VIVADO

Design specifics
----------------

* Synthesis an simulation has been tested using Vivado 2017.1


* 8-bit flash prom can be read at address 0. It can be programmed
  with GRMON version 2.0.30-74 or later.


Simulation 
------------------------

To simulate using Modelsim/Aldec and run systest.c on the Leon design using 
the memory controller from Xilinx use the make targets:

  make soft                    -- compiles software
  make map_xilinx_7series_lib
  make sim_cpci_xc7k
  make mig_7series
  make sim-launch


to use the LEON2 controller for the SRAM (0x40000000), deactivate the MIG controller in xconfig, and uncomment in prom.h the CFG_MIG_7SERIES= 0 section and comment the CFG_MIG_7SERIES= 1( viceversa to restore the MIG controller to execute programs from the DDR3 memory).

"make distclean" is needed when witching from one case to another.

Update xdc file accordingly to CFG_MIG_7SERIES:

#uncomment for mig
#create_clock -period 10.000 -name clkm [get_nets mig_gen.gen_mig.ahb2mig_7series_cpci_xc7k_1/MCB_inst/ui_clk]

#uncomment with no mig
#create_clock -period 10.000 -name clkm [get_nets clkml]


The systest.c provided is a test and assumes that GR1553, 2xGRSPW, GPTIMER and APBUART0 are enabled (the test is intended to work only in simulation).



Synthesis
-----------------

To synthesize the design and program the target, do

  make vivado_cpci_xc7k        (terminal)

or

  make vivado-launch_cpci_xc7k (GUI)


Simulation options
------------------

All options are set either by editing the testbench or specify/modify the generic 
default value when launching the simulator. For Modelsim use the option "-g" i.e.
to enable processor disassembly to console launch modelsim with the option: "-gdisas=1"

USE_MIG_INTERFACE_MODEL - Use MIG simulation model for faster simulation run time
(Option can now be controlled via 'make xconfig')

disas - Enable processor disassembly to console

Selecting External FLASH
------------------------

The KC705 ref design supports Linear BPI flash and Quad SPI flash. Due
to shared pins on the FPGA the two flash types can't co-exist in the design. 
Select flash type by enabling LEON2 memory controller for BPI flash or 
SPIMCTRL for Quad SPI flash in the configuration files for the design.

Quad SPI flash memory is controlled by the configuration mode settings on DIP switch 
SW13 position 5 (M0) and a one-of-two demultiplexer device U64. If mode pin M0 = 1, the 
SPI flash memory device is selected. If mode pin M0 = 0, the Linear BPI flash memory 
device is selected.

Quad SPI flash is only supported by grmon2-2.0.56 or later


Output from GRMON
------------------
Below an example of configuration of the board with GRMON is reported, using the uart to connect 


grmon  -uart /dev/ttyUSB1

  GRMON2 LEON debug monitor v2.0.83 64-bit internal version
  
  Copyright (C) 2017 Cobham Gaisler - All rights reserved.
  For latest updates, go to http://www.gaisler.com/
  Comments or bug-reports to support@gaisler.com
  
  This internal version will expire on 16/02/2018

Parsing -uart /dev/ttyUSB1

Commands missing help:

  using port /dev/ttyUSB1 @ 115200 baud
  Device ID:           0xA705
  GRLIB build version: 4184
  Detected frequency:  50 MHz
  
  Component                            Vendor
  LEON3 SPARC V8 Processor             Cobham Gaisler
  LEON3 SPARC V8 Processor             Cobham Gaisler
  JTAG Debug Link                      Cobham Gaisler
  AHB Debug UART                       Cobham Gaisler
  GR Ethernet MAC                      Cobham Gaisler
  CAN Controller with DMA              Cobham Gaisler
  CAN Controller with DMA              Cobham Gaisler
  GRSPW2 SpaceWire Serial Link         Cobham Gaisler
  GRSPW2 SpaceWire Serial Link         Cobham Gaisler
  MIL-STD-1553B Interface              Cobham Gaisler
  LEON2 Memory Controller              European Space Agency
  Single-port AHB SRAM module          Cobham Gaisler
  AHB/APB Bridge                       Cobham Gaisler
  AHB/APB Bridge                       Cobham Gaisler
  LEON3 Debug Support Unit             Cobham Gaisler
  Generic UART                         Cobham Gaisler
  Multi-processor Interrupt Ctrl.      Cobham Gaisler
  Modular Timer Unit                   Cobham Gaisler
  General Purpose I/O port             Cobham Gaisler
  General Purpose I/O port             Cobham Gaisler
  I2C Slave                            Cobham Gaisler
  Generic UART                         Cobham Gaisler
  Generic UART                         Cobham Gaisler
  Generic UART                         Cobham Gaisler
  Generic UART                         Cobham Gaisler


grmon2> info sys
  cpu0      Cobham Gaisler  LEON3 SPARC V8 Processor    
            AHB Master 0
  cpu1      Cobham Gaisler  LEON3 SPARC V8 Processor    
            AHB Master 1
  ahbjtag0  Cobham Gaisler  JTAG Debug Link    
            AHB Master 2
  ahbuart0  Cobham Gaisler  AHB Debug UART    
            AHB Master 3
            APB: 80007000 - 80008000
            Baudrate 115200, AHB frequency 50.00 MHz
  greth0    Cobham Gaisler  GR Ethernet MAC    
            AHB Master 4
            APB: 80110000 - 80110100
            edcl ip 192.168.0.51, buffer 2 kbyte
  grcan0    Cobham Gaisler  CAN Controller with DMA    
            AHB Master 5
            APB: 80005000 - 80006000
            IRQ: 4
  grcan1    Cobham Gaisler  CAN Controller with DMA    
            AHB Master 6
            APB: 80006000 - 80007000
            IRQ: 5
  grspw0    Cobham Gaisler  GRSPW2 SpaceWire Serial Link    
            AHB Master 7
            APB: 80104000 - 80105000
            IRQ: 6
            Number of ports: 1
  grspw1    Cobham Gaisler  GRSPW2 SpaceWire Serial Link    
            AHB Master 8
            APB: 80105000 - 80106000
            IRQ: 7
            Number of ports: 1
  gr1553b0  Cobham Gaisler  MIL-STD-1553B Interface    
            AHB Master 9
            APB: 8010B000 - 8010C000
            IRQ: 11
            features: BC RT BM, codec clock: 24 MHz 
            Device index: 0
  mctrl0    European Space Agency  LEON2 Memory Controller    
            AHB: 00000000 - 20000000
            AHB: 40000000 - 80000000
            APB: 80000000 - 80000100
            8-bit prom @ 0x00000000
            8-bit static ram: 1 * 2048 kbyte @ 0x40000000
  ahbram0   Cobham Gaisler  Single-port AHB SRAM module    
            AHB: A0000000 - A0100000
            32-bit static ram: 4 kB @ 0xa0000000
  apbmst0   Cobham Gaisler  AHB/APB Bridge    
            AHB: 80000000 - 80100000
  apbmst1   Cobham Gaisler  AHB/APB Bridge    
            AHB: 80100000 - 80200000
  dsu0      Cobham Gaisler  LEON3 Debug Support Unit    
            AHB: 90000000 - A0000000
            AHB trace: 256 lines, 32-bit bus
            CPU0:  win 8, hwbp 2, itrace 256, V8 mul/div, srmmu, lddel 1
                   stack pointer 0x401ffff0
                   icache 2 * 4 kB, 16 B/line
                   dcache 2 * 4 kB, 16 B/line, snoop tags
            CPU1:  win 8, hwbp 2, itrace 256, V8 mul/div, srmmu, lddel 1
                   stack pointer 0x401ffff0
                   icache 2 * 4 kB, 16 B/line
                   dcache 2 * 4 kB, 16 B/line, snoop tags
  uart0     Cobham Gaisler  Generic UART    
            APB: 80001000 - 80001100
            IRQ: 1
            Baudrate 38343, FIFO debug mode
  irqmp0    Cobham Gaisler  Multi-processor Interrupt Ctrl.    
            APB: 80002000 - 80003000
  gptimer0  Cobham Gaisler  Modular Timer Unit    
            APB: 80003000 - 80004000
            IRQ: 8
            8-bit scalar, 2 * 32-bit timers, divisor 50
  gpio0     Cobham Gaisler  General Purpose I/O port    
            APB: 80008000 - 80008100
  gpio1     Cobham Gaisler  General Purpose I/O port    
            APB: 80009000 - 80009100
  adev20    Cobham Gaisler  I2C Slave    
            APB: 8000B000 - 8000C000
            IRQ: 10
  uart1     Cobham Gaisler  Generic UART    
            APB: 80100000 - 80101000
            IRQ: 2
            Baudrate 38343, FIFO debug mode
  uart2     Cobham Gaisler  Generic UART    
            APB: 80101000 - 80102000
            IRQ: 2
            Baudrate 38343, FIFO debug mode
  uart3     Cobham Gaisler  Generic UART    
            APB: 80102000 - 80103000
            IRQ: 2
            Baudrate 38343, FIFO debug mode
  uart4     Cobham Gaisler  Generic UART    
            APB: 80103000 - 80104000
            IRQ: 2
            Baudrate 38343, FIFO debug mode


grmon2> flash
  
  Intel-style 8-bit flash on D[31:24]

  Manuf.        : Intel             
  Device        : MT28F128J3        
  Device ID     : 96f4242703445ece  
  User ID       : ffffffffffffffff  
  
  1 x 16 Mbytes = 16 Mbytes total @ 0x00000000
  
  CFI information
  Flash family  : 1
  Flash size    : 128 Mbit
  Erase regions : 1
  Erase blocks  : 128
  Write buffer  : 32 bytes (limited to 32)
  Lock-down     : Not supported
  Region  0     : 128 blocks of 128 kB
  
grmon2> flash unlock all
  Unlock in progress
  Block @ 0x00fe0000 : code = 0x80  OK
  Unlock complete
  
grmon2> flash erase all 
  Erase in progress
  Block @ 0x00fe0000 : code = 0x80  OK
  Erase complete
  
grmon2> flash load prom.exe 
  00000000 .text                      560B              [===============>] 100%
  Total size: 560B (9.22kbit/s)
  Entry point 0x0
  Image /home/stefano/grlib_git_cpci-xc7k/designs/leon3-gr-cpci-xc7k/prom.exe loaded
  
grmon2> verify prom.srec
  .srec 00000000 prom.srec            1.5kB /   1.5kB   [===============>] 100%
  Total size: 560B (87.84kbit/s)
  Entry point 0x0
  Image of /home/stefano/grlib_git_cpci-xc7k/designs/leon3-gr-cpci-xc7k/prom.srec verified without errors
  
grmon2> flash lock all
  Lock in progress
  Block @ 0x00fe0000 : code = 0x80  OK
  Lock complete

grmon2> load systest.exe
  40000000 .text                     73.6kB /  73.6kB   [===============>] 100%
  40012690 .data                      2.8kB /   2.8kB   [===============>] 100%
  Total size: 76.41kB (96.06kbit/s)
  Entry point 0x40000000
  Image /home/stefano/grlib_git_cpci-xc7k/designs/leon3-gr-cpci-xc7k/systest.exe loaded
  
grmon2> verify systest.exe
  40000000 .text                     73.6kB /  73.6kB   [===============>] 100%
  40012690 .data                      2.8kB /   2.8kB   [===============>] 100%
  Total size: 76.41kB (87.50kbit/s)
  Entry point 0x40000000
  Image of /home/stefano/grlib_git_cpci-xc7k/designs/leon3-gr-cpci-xc7k/systest.exe verified without errors

To connect with jtag cable use -digilent switch. ( for other information refer to the GRMON2 guide)

TODO:
- Update design to support LEON4 
