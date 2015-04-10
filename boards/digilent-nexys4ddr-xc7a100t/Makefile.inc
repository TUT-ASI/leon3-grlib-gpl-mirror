# Since synplify seems to cause a synthsis error involving
# the DSP macro blocks the Spartan 3A technology 
# without DSP is used for synthesis
#
TECHNOLOGY=Artix7
ISETECH="Artix7"
PART=XC7A100T
PACKAGE=csg324
SPEED=-1
SYNFREQ=100
PROMGENPAR= -c FF -s 8192 -u 0 $(TOP).bit -p mcs -spi -w -o digilent-nexys4ddr-xc7a100t

MANUFACTURER=Xilinx
MGCPART=XC7A100T$(PACKAGE)
MGCTECHNOLOGY=ARTIX-7
MGCPACKAGE=$(PACKAGE)
