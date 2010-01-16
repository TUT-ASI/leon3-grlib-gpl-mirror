CC=sparc-elf-gcc
CCOPT=-msoft-float -g

all: rmapapi.h spwapi.h spwapi.c rmapapi.c spw_test_dual.c
	$(CC) $(CCOPT) -o spw_test_dual spw_test_dual.c spwapi.c rmapapi.c

sep: rmapapi.h spwapi.h spwapi.c rmapapi.c spw_test_dual_sep.c
	$(CC) $(CCOPT) -DINITIATOR=0 -DSPW_ADDR=0x80000a00 -DSPW_FREQ=200000 -DAHBFREQ=40000 -DSPW_CLKDIV=1 -o spw_test_dual_targ spw_test_dual_sep.c spwapi.c rmapapi.c
	$(CC) $(CCOPT) -DINITIATOR=1 -DSPW_ADDR=0x80000c00 -DSPW_FREQ=80000 -DAHBFREQ=25000 -DSPW_CLKDIV=0 -o spw_test_dual_init spw_test_dual_sep.c spwapi.c rmapapi.c