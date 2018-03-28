
LEON3 Template design for TerASIC Altera DE4 board
------------------------------------------------------

0verview
--------
The design contains:
  * LEON3 running at 100 MHz
  * 1 GiB DDR2 running at 400 MHz using Quartus soft memory controller IP
  * JTAG debug link connected to on-board USB blaster II
  * One debug UART (AHBUART) and one standard UART (APBUART),
    connected to the serial port according to the position of slide
    switch 0
  * Memory controller to access the on-board flash via GRMON
  * Two GRETH Gigabit Ethernet cores with EDCL, connected to the PHY 
    through Altera's SGMII to GMII bridge IP.
  * Currently, only gigabit operation is supported for the Ethernet
    core and the 10/100 Mbit GRETH cannot be used.

Important notes
---------------
* The SSRAM on the board is not currently supported.
* The flash memory is also used by the board's firmware and to store
  the FPGA designs.
* The Ethernet gigabit cores are disabled by default and are not 
  available in the GPL release of GRLIB.
* The Level-2 cache can be enabled in the design. This requires a
  GRLIB release that includes the Level-2 cache.

Design details
--------------
* Processor error output is mapped to LED 0

* DSU enable is tied HIGH internally
* DSU break is mapped to push button 0
* DSU active is mapped to LED 1

* The system UART is mapped to the UART signals when
  slide switch 0 is HIGH otherwise the AHB (DSU) UART
  debug link is connected to the board's UART signals. 


LED assignments:
    LED7 - unused  
    LED6 - unused
    LED5 - unused
    LED4 - unused
    LED3 - unused
    LED2 - unused
    LED1 - DSU active
    LED0 - DBG error

Push button assignments:
    CPU_RESET_n - Reset LEON system
    BUTTON3     - unused
    BUTTON2     - unused
    BUTTON1     - unused
    BUTTON0     - DSU Break

Slide switches:
    SLIDE_SW3 - unused
    SLIDE_SW2 - unused
    SLIDE_SW1 - Disable EDCL:
        ON  (down, 0) - EDCL is ON for all links at reset
        OFF (up, 1) - EDCL is OFF for all links at reset
    SLIDE_SW0 - Select serial port (J30) UART mapping:
        ON  (down, 0) - is AHB debug UART
        OFF (up,1) - is system's APB UART


Simulation and synthesis
------------------------
* To simulate the design with ModelSim or Riviera first set the
  GRLIB_SIMULATOR environment variable accordingly (see GRLIB 
  documentation). The simulation uses a simplified DDR2 controller.
  Please note that Ethernet doesn't work during simulation and must be
  disabled:

    make vsim [or make riviera]

* Synthesis will work with Quartus 13.1 or newer. To synthesize the 
  design run:

    make qwiz
    make quartus
  
  If Ethernet is enabled and you don't have an Altera's Triple Speed
  Ethernet IP Core license, a time-limited file will be generated.
  Before programming the board you need to move the file:

    mv leon3mp_quartus_time_limited.sof leon3mp_quartus.sof
  
  then program the board with:

    make quartus-prog-fpga

5.1 How to program the flash prom with a FPGA programming file
--------------------------------------------------------------
To program the board's flash permanently, you first have to generate 
an srec file with the firmware and then write it to the flash via 
Grmon. You will need a Quartus installation, and the SREC tools from: 
http://srecord.sourceforge.net/

Launch a Nios II Command Shell, which is part of your Quartus 
installation. On Windows it's in the Start menu, under Nios II. On 
Linux you can find it in $QUARTUS_INST_DIR/nios2eds/nios2_command_shell.sh

In the shell execute the following commands:

  sof2flash --input=leon3mp_quartus.sof --output=leon3mp_quartus.flash --offset=0x00020000 --pfl --optionbit=0x18000 --programmingmode=FPP

At the end of this step you will have generated two files:
  - leon3mp_quartus.flash
  - leon3mp_quartus.map.flash

Execute the following:
  echo "S21501808003FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6" >> leon3mp_quartus.map.flash

Finally merge the two files with:
  srec_cat leon3mp_quartus.flash -byteswap leon3mp_quartus.map.flash -byteswap -output leon3mp.srec

Now you have to write the firmware to the flash. To do so, connect to 
your board with Grmon and execute the following.

  flash unlock all

  flash erase 0x18000 0xC00000

  flash load leon3mp.srec

At this point your board is programmed permanently. You can push the 
RE_CONFIGn button to test it.
