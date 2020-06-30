This LEON design is tailored to the Digilent Arty A7 35T Arty A7 100T.
---------------------------------------------------------

Two FPGAs supported: XC7A35TI and XC7A100TI (default).

To change the synthesis target to XC7A35TI:

Edit the Makefile and change the variable PART accordingly:

#PART=XC7A35TI
PART=XC7A100TI

This is not yet  supported in xconfig.


Simulation and synthesis
------------------------

The design currently supports synthesis with Xilinx Vivado (tested
with Vivado 2018.1).

If enabled by the user, the design uses the Xilinx MIG memory
interface with an AXI interface.  The MIG source code cannot be
distributed due to the prohibitive Xilinx license, so the MIG must be
re-generated with coregen before simulation and synthesis can be done.

Xilinx MIG interface will automatically be generated when Vivado is
launched.

To simulate using GHDL:
  make ghdl
  make ghdl-run

To simulate using XSIM and run systest.c on the Leon design using the
memory controller from Xilinx use the make targets:

  make vivado-launch

To simulate using Modelsim/Aldec and run systest.c on the Leon design using 
the memory controller from Xilinx use the make targets:

  make map_xilinx_7series_lib
  make sim
  make mig_7series (only required if Xilinx MIG is enabled via xconfig)
  make sim-launch

To simulate using Aldec Riviera use the following make targets:

  make map_xilinx_7series_lib
  make riviera
  make mig_series7 (only required if Xilinx MIG is enabled via xconfig)
  make riviera-launch

To synthesize the design, do

  make vivado (or make vivado-launch for the GUI flow)

To generate a timing summaries in vivslack.rpt, vivsetup.rpt and vivhold.rpt:
  make vivslack

To program the FPGA:
  make vivprog

To program bitstream into the flash:
  make vivrom

Design specifics
----------------
To be added

Example GRMON session
---------------------
To be added

