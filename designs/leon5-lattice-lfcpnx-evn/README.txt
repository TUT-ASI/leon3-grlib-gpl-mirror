This design is tailored to the Lattice CertusPRO-NX Evaluation board
---------------------------------------------------------------------

= Introduction =

This directory contains a template design for the CertusPRO-NX Evaluation
board (EVB). The EVB is limited in terms of available external non-volatile
memory.


= Design configuration =
There are few variables that can be used to provide basic/additional
components to the design.

BOARD
	folder name inside boards/ where files needed for the design are stored.

LATTICE_IP
	list the Lattice IPs that you want to get included in the design.
	The corresponding cfg files need to be present inside the folder
	boards/lattice-lfcpnx-evn. Each IP needs to be listed as path to the
	cfg file inside the lattice_ips/ folder. When running "make
	radiant-launch" or "make radiant" the IP cfg will be copied inside the
	design folder and the IP generated. No need to manually generate
	it. Currently the only IP listed is pll_12MHz, which is configured to
	take the 12MHz clock signal from an external oscillator and output the
	clock signal for the design.

A bunch of IPs (SpaceWire, SPI Memory controller) have been included in the
design and they're ready to be used, provided that the user configures some
VHDL constants. To simplify the procedure, the user can run
	   make xconfig
and select the peripherals of interest. The script will edit the needed
parameters once "Save and Exit" is pressed.

Clock frequency: 36 MHz


= Configuration of environment =

The environment variables for using Radiant in command line mode must
be set:

- $PATH must include the Radiant software executables
- $PATH must include Mentor/QuestaSim

Optional settings that affect behaviour of commands:

GRLIB_LATTICE_RADIANT_SIM_PATH
        simulation tool executable folder. If unset then the script 
        will try with the Radiant ModelSim installation.
        
GRLIB_LATTICE_RADIANT_PERFORMANCE
        default value "9_High-Performance_1.0"

GRLIB_LATTICE_RADIANT_SYNTHESIS
        synthesis tool selection. "synplify" or "lse", default is 
        "synplify"
        
GRLIB_LATTICE_RADIANT_SIM_DEVICE
        selects devices for which simulation libraries are built. 
        set to lifcl in the template design Makefile


= Tested Software =
For design building: Radiant 3.2
For simulation: ModelSim 10.7g


= Simulation =

Simulation requires simulation librares to be installed. This can be
done via the command:

           make install-radiant-simlibs

The above commnd builds the simulation libraries. These then need to
be mapped into the local ModelSim/Questa project:

           make map-radiant-simlibs
If lattice simulation libraries were not compiled yet
(i.e. install-radiant-simlibs not run), then the system will
build them before mapping.

After that, simulation can be run by:

           make sim
           make sim-launch 


= Synthesis =

Radiant can use LSE or Synplify Pro for synthesis. Synplify Pro is the
recommended tool and is the default option.

Full automatic synthesis is launched by running:

	  make radiant

To open the design for possible editing and synthesis:

          make radiant-launch

Followed by using the GUI to start the flow and generate a FPGA
programming file.


= Programming the FPGA =

The programming part is done by using Radiant Programmerm which can be
launched from Radiant itself.

To connect to Lattice boards (for programming purposes), you'll need to use
the D2XX drivers (ftdichip.com). While on Windows system their installation is
automatically handled by the system, on Linux systems you'll need to install
them manually (if not provided in any repository). If you install them
manually, you'll need to disable the kernel ftdi module (ftdi_sio) before
programming the fpga, otherwise Radiant won't be able to see the FTDI
connections. After programming, you'll need to reload them if you use grmon
with default settings.

To unload ftdi_sio drivers
        sudo modprobe -r ftdi_sio

To load ftdi_sio drivers
        sudo modprobe ftdi_sio


= PC Debug connection =

A debug connection to the design can be establish by just using the USB
connection used for programming the board.

If in a Linux environment, remember to reload the ftdi_sio module before
connecting with grmon. Then issue
	   grmon -uart /dev/ttyUSBx
with x being the number related to the UART connection. Remember that the uart
part is connected to the B part of the FTDI chip, therefore you'll need to use
the second occurrence of the ttyUSB pair that appears.


EOF
