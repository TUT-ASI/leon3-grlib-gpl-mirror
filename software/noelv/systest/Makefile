#--------------------------------------------------------------------
# Include Paths
#--------------------------------------------------------------------

VPATH  = $(GRLIB)/software/noelv/systest
VPATH += sw
XINC  = -I$(GRLIB)/software/noelv/systest
XINC += -Isw

#VPATH += $(GRLIB)/software/noelv/systest/uart
#XINC += -I$(GRLIB)/software/noelv/systest/uart

LD =
LD_SYSTEST ?= $(GRLIB)/software/noelv/systest/noel.link
LD_PROM ?= $(GRLIB)/software/noelv/systest/prom.link
#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------
XLEN ?= 64
ifeq ($(XLEN), 64)
	RISCV_ABI ?= lp$(XLEN)
else
	RISCV_ABI ?= ilp$(XLEN)
endif	
RISCV_ARCH ?= rv$(XLEN)ima
RISCV_PREFIX ?= riscv-gaisler-elf-

XCC = $(RISCV_PREFIX)gcc $(XINC)
XAS = $(RISCV_PREFIX)gcc -c -I. $(XINC)
XAR = $(RISCV_PREFIX)ar
XCFLAGS = -mcmodel=medany -static -std=gnu99 -O2 -march=$(RISCV_ARCH) -mabi=$(RISCV_ABI) -Wl,--no-gc-sections
XCFLAGS_PROM = -mcmodel=medany -static -std=gnu99 -O2 -march=$(RISCV_ARCH) -mabi=$(RISCV_ABI) -Wl,--no-gc-sections -nostdlib

ifeq ("$(LD)", "")
	LDFLAGS = -qbsp=2020q4
else
	LDFLAGS = -qbsp=2020q4 -T$(LD)
endif
XLDFLAGS=-L./ libnoeltests.a $(LDFLAGS)

LINK = $(XCC) -T$(LD)
#LINK = $(XCC) -Ttext=0x40000000
##LINK = $(XCC)
LINK_OPTS = -static -nostdlib -nostartfiles -lm -lgcc
LDLIBS =

OBJDUMP = $(RISCV_PREFIX)objdump --disassemble-all --disassemble-zeroes

OBJCOPY = $(RISCV_PREFIX)objcopy
#OBJCOPY_OPTS = --srec-len=16 --srec-forceS3 --gap-fill=0 --pad-to=0x40100000
OBJCOPY_OPTS = --srec-len=16 --srec-forceS3 --gap-fill=0
PROM_OPTS = --srec-len=16 --srec-forceS3 --gap-fill=0
SECTIONS = --remove-section=.comment --remove-section=.riscv.attributes

DTB = noelv.dtb

PROGS = 
#apbuart
OFILES = $(PROGS:%=%.o)

#--------------------------------------------------------------------
# Build Templates
#--------------------------------------------------------------------

%.o: %.c
	$(XCC) $(XCFLAGS) -c $<

%.o: %.S
	$(XCC) $(XCFLAGS) -c $<

%.dtb: %.dts
	dtc -I dts $< -O dtb -o $@

%.elf: %.c
	$(XCC) $(XCFLAGS) $(LDFLAGS) $< -o $@

%.elf: %.S
	$(XCC) $(XCFLAGS) $(LDFLAGS) $< -o $@

%.srec: %.elf
	$(OBJCOPY) $(OBJCOPY_OPTS) $(SECTIONS) -O srec $< $@

libnoeltests.a: $(OFILES)
	$(XAR) -cr libnoeltests.a $(OFILES)

#--------------------------------------------------------------------
# Test Programs
#--------------------------------------------------------------------

prom.elf: prom.S $(LD_PROM)
	$(XCC) $(XCFLAGS_PROM) -T$(LD_PROM) $< -o $@

prom.srec: prom.elf
	$(OBJCOPY) $(OBJCOPY_OPTS) $(SECTIONS) -O srec $< $@

systest.elf: systest.c report_device.o libnoeltests.a $(LD_SYSTEST)
	$(XCC) $(XCFLAGS) report_device.o $(XLDFLAGS) $< -o $@

ram.srec: systest.elf
	$(OBJCOPY) $(OBJCOPY_OPTS) $(SECTIONS) -O srec $< $@

systest_small.elf: systest.c crt.o report_device.o libnoeltests.a $(LD_SYSTEST)
	$(XCC) $(XCFLAGS) -T$(LD_SYSTEST) -nostdlib report_device.o crt.o $(XLDFLAGS) $< -o $@

#--------------------------------------------------------------------
# Soft
#--------------------------------------------------------------------

soft: prom.srec ram.srec

#--------------------------------------------------------------------
# Clean Up
#--------------------------------------------------------------------

CLEAN += soft-clean 

soft-clean:
	-rm -rf *.o *.a *.elf

