This design is tailored to the GR740-mini board
---------------------------------------------------------------------

= Introduction =

This directory contains a template design for the GR740-mini board.


= Design configuration =
There are few variables that can be used to provide basic/additional
components to the design.

BOARD
	folder name inside boards/ where files needed for the design are stored.

LATTICE_IP
	list the Lattice IPs that you want to get included in the design.
	The corresponding files need to be present inside the corresponding
	board folder in boards/ . When running "make radiant-launch" the
	IP folder will be copied inside the design folder. Before building
	the design, the user needs to open the IP (inside radiant) and
	generate it. The main IP is pll_125I_50O, which is configured to
	take the 125MHz clock signal from an external oscillator and generate 
	a main clock (50MHz) for the design.


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

= Simulation =

Simulation requires simulation librares to be installed. This can be
done via the command:
           
           make install-radiant-simlibs

The above commnd builds the simulation libraries. These then need to
be mapped into the local ModelSim/Questa project:

           make map-radiant-simlibs

After that, simulation can be run by:

           make sim
           make sim-launch 


= Synthesis =

Radiant can use LSE or Synplify Pro for synthesis. Synplify Pro is the
recommended tool and is the default option.

Synthesis is launched by running:

          make radiant-launch

Followed by using the GUI to start the flow and generate a FPGA
programming file.


EOF
