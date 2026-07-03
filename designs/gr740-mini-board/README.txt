This design is tailored to the Lattice CertusPro-NX targeting the GR740-MINI board
---------------------------------------------------------------------

The design has been evaluated and validated with the following tools and revision:   

Lattice radiant 2023.1 
Mentor ModelSim 10.7g 


Libraries need to be installed, use following command:
           make install-radiant-simlibs

The above command builds the simulation libraries. These then needs to
be mapped into the local ModelSim/Questa project:
           make map-radiant-simlibs

To run a simulation type: 
(Note that the testbench is based on the JTAG-link)  
           make sim-run (Terminal)
           make sim-launch (GUI)

For synthesizes, place & route and generation of bitstreams, open the radiant tool: 
           make radiant-launch

To clean the project folder when needed for rebuilding use: 
	   make clean

### Project specific ###

There are some signals that shares the same pins (FMC+ connector), please investigate and modify the .pdc file to match the current design. 

There is an external simulation memory model implemented in the testbench for the nandflashcontroller test.  
This model is not provided in the standard GRLIB, note that the design in the FPGA will still work even if the testbench doesn't pass due to missing external simulation model
If the external simulation memory model is added in GRLIB, then this command below needs to be performed before the simulation. 
	make sim_mem

In this design, a DDR3 wrapper is added to the Lattice DDR3 memory controller. Note that this memory controller needs a license, but can be compiled in evaluation mode where the bitstream only will run and last for approximate 2-4 hours. To add this evaluation mode make sure that the "IP Evaluation" box is enabled under Project > Active Strategy > Bitstream setting, in the radiant tool. If the DDR3 memory controller is enabled make sure to modify the corresponding pins in the .pcd file
EOF
