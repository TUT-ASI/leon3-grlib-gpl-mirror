DHRY-LDFLAGS =
DHRY-LINK = -T$(TESTS_LOCAL)/benchmark.ld

DHRY-CFLAGS := -O3 -DTIME -DNOENUM -Wno-implicit -save-temps
DHRY-CFLAGS += -fno-builtin-printf -fno-common -falign-functions=4

#Uncomment below for FPGA run, default DHRY_ITERS is 2000 for RTL
#DHRY-CFLAGS += -DDHRY_ITERS=20000000

SRC = $(DHRYSTONE_LOCAL)/dhry_1.c  $(DHRYSTONE_LOCAL)/dhry_2.c
HDR = $(DHRYSTONE_LOCAL)/dhry.h

XCFLAGS += $(DHRY-CFLAGS) -Xlinker --defsym=__stack_size=0x800 -Xlinker --defsym=__heap_size=0x1000

dhrystone: $(SRC) $(HDR) 
	$(XCC) $(XCFLAGS) $(SRC) $(DHRY-LDFLAGS) $(DHRY-LINK) $(LDLIBS) -o $@
	$(OBJCOPY) $(OBJCOPY_OPTS) $(EXTRA_PROM) $(SECTIONS) -O srec $@ ram.srec

dhrystone-clean:
	rm -f *.i *.s *.o dhrystone dhrystone.hex

