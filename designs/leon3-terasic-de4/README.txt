
LEON3 Template design for TerASIC Altera DE4 board
------------------------------------------------------

0verview
--------
The design contains:
  * LEON3 running at 50 MHz
  * 1 GiB DDR2 running at 400 MHz using Quartus soft memory controller IP
  * JTAG debug link connected to on-board USB blaster II
  * One debug UART (AHBUART) and one standard UART (APBUART),
    connected to the serial port according to the position of slide
    switch 0
  * Memory controller to access the on-board flash via GRMON
  * Two GRETH Gigabit Ethernet cores with EDCL, connected to the PHY 
    through Altera's SGMII to GMII bridge IP.

Important notes
---------------
* The SSRAM on the board is not currently supported.
* The flash memory is also used by the board's firmware and to store
  the FPGA designs.
* The Ethernet gigabit cores are disabled by default and are not 
  available in the GPL release of GRLIB.

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
    LED5 - Ethernet 1 link up
    LED4 - Ethernet 1 carrier sense
    LED3 - Ethernet 0 link up
    LED2 - Ethernet 0 carrier sense
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
    SLIDE_SW1 - unused
    SLIDE_SW0 - Select serial port (J30) UART mapping:
        ON  (left, 0) - is AHB debug UART
        OFF (right,1) - is system's APB UART


Simulation and synthesis
------------------------
* To simulate the design with ModelSim or Riviera first set the
  GRLIB_SIMULATOR environment variable accordingly (see GRLIB 
  documentation). The simulation uses a simplified DDR2 controller.
  Please note that Ethernet doesn't work during simulation and must be
  disabled:

    make vsim [or make riviera]

* Synthesis will work with Quartus 13.1 or newwer. To synthesize the 
  design run:

    make qwiz
    make quartus
  
  If Ethernet is enabled and you don't have an Altera's Triple Speed
  Ethernet IP Core license, a time-limited file will be generated.
  Before programming the board you need to move the file:

    mv leon3mp_quartus_time_limited.sof leon3mp_quartus.sof
  
  then program the board with:

    make quartus-prog-fpga
