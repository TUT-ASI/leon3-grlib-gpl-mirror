VPATH=$(GRLIB)/software/leon5
SYSTINC=$(GRLIB)/software/systest/include
XINC=-I$(GRLIB)/software/leon5 -I$(GRLIB)/software/l2c
XINC+=-I$(SYSTINC)
XTARGET=sparc-gaisler-elf
XCC=$(XTARGET)-gcc $(XINC) $(BOPT)
XAS=$(XTARGET)-gcc -c -I. $(XINC) $(BOPT)
XAR=$(XTARGET)-ar
XOBJCOPY=$(XTARGET)-objcopy
XOBJDUMP=$(XTARGET)-objdump

XCFLAGS=-O2 -msoft-float
XCFLAGS+=-Wa,-Aleon
XLDFLAGS=lib3tests.a $(LDFLAGS)

# Use linkprom in current directory if existsing, otherwise the default. The
# variable PROMLDSCRIPT can be overridden by local Makefile in both cases.
ifneq ("$(wildcard linkprom)","")
  PROMLDSCRIPT ?= linkprom
else
  PROMLDSCRIPT ?= $(GRLIB)/software/leon5/linkprom.default
endif

SOFT_SRECS = ram.srec

# Build prom.srec only if prom.h exists
ifneq ("$(wildcard prom.h)","")
  SOFT_SRECS += prom.srec
endif

PROGS = grcanfd apbuart divtest multest regtest \
	cache gpio ramfill ramtest irqmp leon3_test gptimer \
	mulasm cacheasm spwtest mptest fpu grfpu_ops \
	base_test grfpu_test can_oc mmu mmu_asm mmu_so_check pcitest greth \
	amba dsu3 greth_api grcan grcanfd grdmac grdmac2 grspfi grwizl \
	spictrl i2cmst misc spimctrl svgactrl apbps2 \
	i2cslv i2c l2c \
	report report_device report_stdio \
	grusbdc rt_1553 brm_1553 pcif grtc grtm satcan memscrub_test \
	ftahbram ftlib ftsrctrl ftmctrl bch l2timers l2irqctrl leon2_test \
	grpwm grhcan brm grusbhc leon4_test base_test4 griommu l34stat ftddr2spa \
	router greth_throughput grpci2 gr1553b_test spwrouter \
	cgtest privtest privtest_asm mmudmap leon_tsc dpr_test mem_test grspwtdp \
	rextest rextest_asm awptest \
	grfpu_test5 fpu5 leon5_test base_test5 \
	rextest rextest_asm awptest leon5asm

FPROGS=$(shell for i in $(PROGS); do \
			if [ -r $(GRLIB)/software/leon5/$$i.c -o -r $(GRLIB)/software/leon5/$$i.S ]; then \
				echo $$i; \
			fi; \
			if [ -r $(GRLIB)/software/systest/$$i.c -o -r $(GRLIB)/software/systest/$$i.S ]; then \
				echo $$i; \
			fi; \
		done; \
		if [ -r $(GRLIB)/software/greth/greth_api.c ]; then \
			echo greth_api; \
		fi; \
		if [ -r $(GRLIB)/software/l2c/l2capi.c ]; then \
			echo l2capi; \
		fi)

FPROGS+=$(EXTRA_PROGS)
FPROGS += isrhelper
FPROGS += inthelper

VPATH+=$(GRLIB)/software/l2c
VPATH+=$(GRLIB)/software/systest

OFILES = $(FPROGS:%=%.o)

%.o: %.c
	$(XCC) $(XCFLAGS) -c  $<

%.o: %.S
	$(XCC) $(XCFLAGS) -mcpu=leon5 -c  $<

%.exe.dis: %.exe
	$(XOBJDUMP) -d $< > $@

greth.o: XINC+=-I$(GRLIB)/software/greth

fpu.o: fpu.c
	$(XCC) -ffast-math -O3 -c  $<

multest.o: multest.c
	$(XCC) $(XCFLAGS) -mcpu=leon5 -c $<

divtest.o: divtest.c
	$(XCC) $(XCFLAGS) -mcpu=leon5 -c $<

greth_api.o : $(GRLIB)/software/greth/greth_api.c
	$(XCC) $(XCFLAGS) -c $<

cgtest.o : cgtest.c
	$(XCC) -c  $<

gptimer.o : gptimer.c $(SYSTINC)/gptimer.h $(SYSTINC)/gpio.h

grspwtdp.o : grspwtdp.c $(SYSTINC)/grspwtdp.h $(SYSTINC)/grspwtdp-regs.h

dpr_test.o: dpr_test.c
	$(XCC) -O0 -msoft-float -c  $<

#mptest.o: mptest.c
#	$(XCC) -msoft-float -O -c  $<
#


lib3tests.a: $(OFILES)
	$(XAR) -cr lib3tests.a $(OFILES)

soft: $(SOFT_SRECS) $(EXTRA_SOFT)

prom.o: prom.S prom.h
	$(XAS) $<
prom.exe: prom.o
	$(XCC) -nostdlib -T$(PROMLDSCRIPT) -N -L./ -nostartfiles -o prom.exe $<

prom.srec: prom.exe
	$(XOBJCOPY) -O srec $(EXTRA_PROM) prom.exe prom.srec

systest.exe: systest.o bcc2sim.o lib3tests.a
	$(XCC) $(XCFLAGS) systest.o bcc2sim.o $(XLDFLAGS) -o systest.exe

# NOTE: .bss section included in ram.srec to allow skipping bss init
ram.srec: systest.exe
	$(XOBJCOPY) -O srec --gap-fill 0 --set-section-flags .bss=alloc,contents,load systest.exe ram.srec

soft-clean:
	-rm -rf *.o *.exe *.a

mmusoft:
	make -f Makefile.img mmusoft

