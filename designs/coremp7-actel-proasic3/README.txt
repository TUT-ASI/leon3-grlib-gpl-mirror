CoreMP7/GRLIB on Actel CoreMP7-1000 board
=========================================

0. Introduction
--------------

This design instantiates a CoreMP7 processor together with a GRLIB bridge 
which allows the CoreMP7 to interface with GRLIB cores. The bridge has been
developed as part of a master thesis work at Gaisler Research.

The folder grlib/lib/techmap/proasic3 should contain the VHDL files needed for
the instantiation of the CoreMP7 as well as the CoreMP7Bridge. These files are 
taken from the CoreConsole IP library v. 1.4. If these files are not present
in your GRLIB tree you need to copy them from the Core Console IP library. 
GRLIB has a make target that will copy the necessary files. An example of how 
to import the files in a CYGWIN environment is shown below. CoreConsole 1.4 
is, in this example, installed under /cygdrive/e/CoreConsole_v1.4 
(or E:\CoreConsole_v1.4):

$ make import-actel-cc
CORECONSOLE environment variable is not correctly set!
$ export CORECONSOLE=/cygdrive/e/CoreConsole_v1.4
$ make import-actel-cc
Importing CoreMP7 files from Actel CoreConsole IP Library
 Importing A7WrapMaster.vhd A7WrapSM.vhd CoreMP7Bridge_a3p.vhd Sync.vhd uj_jtag.vhd to lib/techmap/proasic3
 Importing arm_synplify.vhd to lib/techmap/proasic3
$

If the 'make import-actel-cc' command fails the files can be manually
copied from the CoreConsole repository. The paths below are relative to:
<coreconsole directory>/repository/Components/Actel/DirectCore/
Copy A7WrapMaster.vhd, A7WrapSM.vhd, CoreMP7Bridge_a3p.vhd, Sync.vhd,
and uj_jtag.vhd from CoreMP7Bridge/2.1/rtl/vhdl/o to
<grlib>/lib/techmap/proasic3. Copy arm_synplify.vhd from
A7S/2.0/M7A3P1000-2/debug/timingshell/vhdl to <grlib>/lib/techmap/proasic3

Components for these files are instantiated together with the GRLIB wapper to
form the cmp7grlib component. The design files for this component are available
under lib/gaisler/coremp7

1. Clocking
-----------

The design uses the Proasic3 PLL to divide the 48 MHz clock to a lower 
frequency. For this to work, jumper JP42 must be set to enable the power to the
VCCPLF. The board is shipped with this jumper in 'off' mode, thereby inhibiting
the PLL.

Some useful PLL parameters:

FREQ    MUL   DIV   ODIV
 20      15    9     4
 25      25   12     4
 30      45    9     8
 32       6    9     1
 34      51    9     8
 35      35    12    4

2. SSRAM
--------

The SSRAM can be interfaced with the SSRCTRL sync-ram controller, or the leon2 
async-sram MCTRL memory controller. If SSRCTRL is used, the J49 must be open 
to run the SSRAM in pipeline mode. If the MCTRL is used, J49 should be closed
and zero-waitstates should be used in MCTRL.

3. System
---------

The output from GRMON should look something like this:

$ grmon

 GRMON LEON debug monitor v1.1.29 (evaluation version)

 Copyright (C) 2004,2005 Gaisler Research - all rights reserved.
 For latest updates, go to http://www.gaisler.com/
 Comments or bug-reports to support@gaisler.com

 This evaluation version will expire on 10/12/2008
 using port /dev/ttyS0 @ 115200 baud

 GRLIB build version: 2996

 initialising ........
 detected frequency:  30 MHz

 Component                            Vendor
 CoreMP7                              Actel Corporation
 AHB Debug UART                       Gaisler Research
 LEON2 Memory Controller              European Space Agency
 AHB/APB Bridge                       Gaisler Research
 Generic APB UART                     Gaisler Research
 Multi-processor Interrupt Ctrl       Gaisler Research
 Modular Timer Unit                   Gaisler Research
 CoreMP7 GRLIB wrapper                Gaisler Research

 Use command 'info sys' to print a detailed report of attached cores

grlib> inf sys
00.ac:001   Actel Corporation  CoreMP7 (ver 0x1)
             ahb master 0
01.01:007   Gaisler Research  AHB Debug UART (ver 0x0)
             ahb master 1
             apb: 80000700 - 80000800
             baud rate 115200, ahb frequency 30.00
00.04:00f   European Space Agency  LEON2 Memory Controller (ver 0x1)
             ahb: 40000000 - 60000000
             ahb: 20000000 - 40000000
             ahb: 00000000 - 40000000
             apb: 80000000 - 80000100
             32-bit prom @ 0x40000000
             32-bit static ram: 1 * 2048 kbyte @ 0x00000000
01.01:006   Gaisler Research  AHB/APB Bridge (ver 0x0)
             ahb: 80000000 - 80100000
01.01:00c   Gaisler Research  Generic APB UART (ver 0x1)
             irq 2
             apb: 80000100 - 80000200
             baud rate 38265
02.01:00d   Gaisler Research  Multi-processor Interrupt Ctrl (ver 0x3)
             apb: 80000200 - 80000300
03.01:011   Gaisler Research  Modular Timer Unit (ver 0x0)
             irq 8
             apb: 80000300 - 80000400
             8-bit scaler, 2 * 32-bit timers, divisor 30
04.01:065   Gaisler Research  CoreMP7 GRLIB wrapper (ver 0x1)
             apb: 80000400 - 80000500
grlib>

4. Synthesis
------------

Synthesis has been done with Synplify-9.0 beta. It is IMPERATIVE that retiming
is NOT enabled, or a corrupt netlist will be created. Maximum frequency is in 
the range of 30 - 35 MHz.

The easiest way to get a working system is:

1. Execute 'make import-actel-cc'
2. Execute 'make scripts'
3. Synthesize using Synplify
4. Start Actel Designer by executing 'make actel-launch-synp'
5. Import the CoreMP7 black-box. Do this by clicking the "File" menu and select
   "Import Source Files". Add the file arm_designer.cdb from 
   {CoreConsole dir}/repository/Components/Actel/DirectCore/A7S/2.0/M7A3P1000-2/debug/layout.
6. After adding this file, the programming file can be generated as usual

IMPORTANT: To disable debug, the generic "DEBUG" in the entity cmp7grlib in 
leon3mp.vhd needs to be set to 0 (instead of 2). Also, in step 5 above the 
arm_designer.cdb file needs to be imported from 
{CoreConsole dir}/repository/Components/Actel/DirectCore/A7S/2.0/M7A3P1000-2/nodebug/layout
You may also be required to copy the corresponding arm_synplify.vhd file as
described at the start of this README file.

5. Simulation
-------------

The design can not be simulated with the included test bench. The library does 
not include a simulation model of the CoreMP7 processor. To set up a simulation
a BFM model of the processor can be instantiated. However, the user must set up 
this simulation environment on her own.

6. Software
-----------

System software for CoreMP7/GRLIB can be found in the software subdirectory. Please see
software/README.txt for further information.

