Overview
--------

Note: This design is EXPERIMENTAL. Simulation is currently not supported.

This LEON3 design is tailored for the Altera Cyclone V SX SoC on the
Terasic Sockit board synthesizable with Quartus II 14.1

Design contains:
  * LEON3 running at 62.5 MHz
  * 1 GiB DDR3 running at 300 MHz using Quartus soft memory controller IP
  * FPGA2HPS bridge allowing the LEON3 system to access the hard processor
    system peripherals.
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

* The JTAG debug link requires a system clock frequency of at least 60 MHz
  to function.

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

Memory map:
  0x00000000-0x1FFFFFFF             Unmapped
  0x20000000-0x200FFFFF  APBCTRL    APB register area
         000-       0FF               Unused
         100-       1FF               Unused
         200-       2FF    IRQMP      IRQ controller regs
         300-       3FF    GPTIMER    Timer registers
         400-       6FF               Unused
         700-       7FF               Unused
         800-       AFF               Unused
         C00-     FEFFF               Unused
       FF000-     FFFFF    APBCTRL    APB plug'n'play information ROM
  0x40000000-0x7FFFFFFF  MEMCTRL1   DDR3 memory
  0x80000000-0xBFFFFFFF  	    Unused
  0xCF000000-0xCFFFFFFF  FPGA2HPS   FPGA to HPS bridge
  0xD0000000-0xDFFFFFFF  DSU        Debug Support Unit
  0xE0000000-0xFFFFEFFF             Unmapped
  0xFFFFF000-0xFFFFFFFF  AHBCTRL    Plug'n'play information ROM

Interrupts:
  8 - Timer

Programming
-----------
To synthesize the design (requires Quartus II 14.1), first build the megafunctions 
using "make qwiz", then use the "make quartus" command to synthesize.

The "make quartus-prog-fpga" command does not work with this version,
instead it will need to be programmed through the quartus programmer
gui.

Debugging can be done over the same interface using grmon -altjtag.



