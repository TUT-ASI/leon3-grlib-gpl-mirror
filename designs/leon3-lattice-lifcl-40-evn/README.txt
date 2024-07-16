This design is tailored to the Lattice CrossLink-NX Evaluation board
---------------------------------------------------------------------

= Introduction =

This directory contains a template design for the CrossLink-NX
Evaluation board (EVB). The EVB is limited in terms of logic resources
on the FPGA and available external non-voltile memory.

= Design configuration =
There are few variables that can be used to provide basic/additional
components to the design.

BOARD
	folder name inside boards/ where files needed for the design are stored.

LATTICE_IP
	list the Lattice IPs that you want to get included in the design.
	The corresponding cfg files need to be present inside the folder
	boards/lattice-lifcl-40-evn. Each IP needs to be listed as path to the
	cfg file inside the lattice_ips/ folder. When running "make
	radiant-launch" or "make radiant" the IP cfg will be copied inside the
	design folder and the IP generated. No need to manually generate
	it. To make the design compatible with Radiant 2022.1, we've
	instantiated an oscillator (osc_150mhz) which feeds a PLL
	(pll_150i_60o). Below you'll find more info on this topic.

Design clock frequency: 60MHz

A bunch of GRLIB IPs (CAN, CAN FD, SpaceWire, SPI Memory controller) have been
included in the design and they're ready to be used,provided that the user
configures some VHDL constants. To simplify the procedure, the user can run
	   make xconfig
and select the peripherals of interest. The script will edit the needed
parameters once "Save and Exit" is pressed.

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
For design building: Radiant 3.2, 2022.1
For simulation: ModelSim 10.7g

    RADIANT 2022.1
    The new pll IP in Radiant 2022.1 and up doesn't allow for input clocks
    below 18MHz. The Crosslink Evaluation board provides only a 12MHz clock to
    the FPGA, as those at higher frequencies are bound to some SERDES
    connections. Therefore we now instantiate the internal oscillator and make
    it output a 150MHz clock which then feeds the PLL.


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


= PC Debug connection =
To establish a debug connection to the design from a pc, you'll need
additional equipment to go from a USB connection to GPIO pins, as the uart tx
signal is routed to PMOD0_5, while uart rx is routed to PMOD0_1.

EOF
