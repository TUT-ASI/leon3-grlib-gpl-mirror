#--------------------------------------------------------------------
# Include Paths
#--------------------------------------------------------------------

VPATH = $(GRLIB)/software/noelv
XINC = -I$(GRLIB)/software/noelv

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

RISCV_PREFIX ?= riscv$(XLEN)-unknown-elf-
XCC = $(RISCV_PREFIX)gcc $(XINC)
XAS = $(RISCV_PREFIX)gcc -c -I. $(XINC)
XAR = $(RISCV_PREFIX)ar
RISCV_ARCH ?= rv$(XLEN)im
XCFLAGS = -mcmodel=medany -static -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf -march=$(RISCV_ARCH)

LINK = $(XCC) -Tlink.ld
LINK_OPTS = -static -nostdlib -nostartfiles -lm -lgcc
LDLIBS =

OBJDUMP = $(RISCV_PREFIX)objdump --disassemble-all --disassemble-zeroes

OBJCOPY = $(RISCV_PREFIX)objcopy
OBJCOPY_OPTS = --srec-len=16 --srec-forceS3 --gap-fill=0 --pad-to=0x40100000
PROM_OPTS = --srec-len=16 --srec-forceS3 --gap-fill=0
SECTIONS = --remove-section=.comment --remove-section=.riscv.attributes

DTB = noelv.dtb

OBJCOPY_CMD= $(OBJCOPY) $(PROM_OPTS) $(SECTIONS)

#--------------------------------------------------------------------
# Test Programs
#--------------------------------------------------------------------



#--------------------------------------------------------------------
# Install Toolchain
#--------------------------------------------------------------------

TOOLCHAIN_REPO = https://github.com/riscv/riscv-gnu-toolchain
TOOLCHAIN = $(GRLIB)/software/noelv/riscv-gnu-toolchain
RTOOLCHAIN = $(realpath $(TOOLCHAIN))
ifeq ($(XLEN), 64)
  BUILD_OPTS  = --with-arch=rv$(XLEN)im --with-abi=lp$(XLEN)d
  RISCV_ABI  ?= lp64d
else
  BUILD_OPTS  = --with-arch=rv$(XLEN)im --with-abi=ilp$(XLEN)d
  RISCV_ABI  ?= ilp32d
endif

update-riscv-toolchain:
	if !(test -r "$(TOOLCHAIN)/.git"); then \
	git clone -b master --depth=1 -n --recursive $(TOOLCHAIN_REPO) $(TOOLCHAIN); \
	cd $(TOOLCHAIN); git checkout master; \
	fi; \
	cd $(TOOLCHAIN); git pull origin master; git submodule update --init --recursive;

install-riscv-toolchain: update-riscv-toolchain
	cd $(TOOLCHAIN); ./configure --prefix=$(RTOOLCHAIN) $(BUILD_OPTS); make;
	make install-riscv-fesvr

FESVR_REPO = https://github.com/riscv/riscv-fesvr
FESVR = $(TOOLCHAIN)/riscv-fesvr

update-riscv-fesvr:
	if !(test -r "$(FESVR)/.git"); then \
	git clone -b master --depth=1 -n --recursive $(FESVR_REPO) $(FESVR); \
	cd $(FESVR); git checkout master; \
	fi; \
	cd $(FESVR); git pull origin master; git submodule update --init --recursive;

install-riscv-fesvr: update-riscv-fesvr
	cd $(FESVR); rm -rf build; mkdir build
	cd $(FESVR)/build; ../configure --prefix=$(RTOOLCHAIN)
	cd $(FESVR)/build; make install

#--------------------------------------------------------------------
# Install Tests
#--------------------------------------------------------------------

TESTS_REPO = https://github.com/riscv/riscv-tests
TESTS = $(GRLIB)/software/noelv/riscv-tests
TESTS_LOCAL = $(GRLIB)/software/noelv/tests

update-riscv-tests:
	if !(test -r "$(TESTS)/.git"); then \
	git clone -b master --depth=1 -n --recursive $(TESTS_REPO) $(TESTS); \
	cd $(TESTS); git checkout master; \
	fi; \
	cd $(TESTS); git pull origin master; git submodule update --init --recursive;

# Regarding the updated pmp.c copied below, it would perhaps be better if
# it could be uploaded to the github repository in some form.
patch-riscv-tests: $(TESTS_LOCAL)
	cp -rf $(TESTS_LOCAL)/Makefile     $(TESTS)/benchmarks || true
	cp -rf $(TESTS_LOCAL)/coremark     $(TESTS)/benchmarks || true
	cp -rf $(TESTS_LOCAL)/primes       $(TESTS)/benchmarks || true
	cp -rf $(TESTS_LOCAL)/capi.h       $(TESTS)/benchmarks/common || true
	cp -rf $(TESTS_LOCAL)/crt.S        $(TESTS)/benchmarks/common || true
	cp -rf $(TESTS_LOCAL)/noelv.ld     $(TESTS)/benchmarks/common || true
	cp -rf $(TESTS_LOCAL)/util.h       $(TESTS)/benchmarks/common || true
	cp -rf $(TESTS_LOCAL)/syscalls.c   $(TESTS)/benchmarks/common || true
	cp -rf $(TESTS_LOCAL)/dhrystone.h  $(TESTS)/benchmarks/dhrystone || true
	cp -rf $(TESTS_LOCAL)/pmp.c        $(TESTS)/benchmarks/pmp || true
	cp -rf $(TESTS_LOCAL)/encoding.h   $(TESTS)/env || true
	cp -rf $(TESTS_LOCAL)/riscv_test.h $(TESTS)/env/p || true
	cp -rf $(TESTS_LOCAL)/link.ld      $(TESTS)/env/p || true
	cp -rf $(TESTS_LOCAL)/uart         $(TESTS) || true

install-riscv-tests: update-riscv-tests
	-cd $(TESTS); autoconf; ./configure --prefix=$(RTOOLCHAIN); make; make install;
	make patch-riscv-tests

#--------------------------------------------------------------------
# Install Torture Framework
#--------------------------------------------------------------------

TORTURE_REPO = https://github.com/ucb-bar/riscv-torture
TORTURE = $(GRLIB)/software/noelv/riscv-torture
TORTURE_LOCAL = $(GRLIB)/software/noelv/torture

update-riscv-torture:
	if !(test -r "$(TORTURE)/.git"); then \
	git clone -b master --depth=1 -n --recursive $(TORTURE_REPO) $(TORTURE); \
	cd $(TORTURE); git checkout master; \
	fi; \
	cd $(TORTURE); git pull origin master; git submodule update --init --recursive;

install-riscv-torture: update-riscv-torture $(TORTURE_LOCAL)/default.config
	cp $(TORTURE_LOCAL)/default.config $(TORTURE)/config;
	cp $(TORTURE_LOCAL)/Makefile $(TORTURE)/output;

#--------------------------------------------------------------------
# Install RISCV-DV Framework
#--------------------------------------------------------------------

DV_REPO = https://github.com/google/riscv-dv
DV = $(GRLIB)/software/noelv/riscv-dv
DV_LOCAL = $(GRLIB)/software/noelv/dv
DV_OPTS = -cmp_opts "+define+RISCV_CORE_SETTING=$(DV_LOCAL)/noelv_core_setting.sv"

update-riscv-dv:
	if !(test -r "$(DV)/.git"); then \
	git clone -b master --depth=1 -n --recursive $(DV_REPO) $(DV); \
	cd $(DV); git checkout master; \
	fi; \
	cd $(DV); git pull origin master; git submodule update --init --recursive;

install-riscv-dv:
	cp $(DV_LOCAL)/run $(DV);
	cp $(DV_LOCAL)/riscv_asm_program_gen.sv $(DV)/src;
	cd $(DV); ./run -test all $(DV_OPTS);

#--------------------------------------------------------------------
# Install RISC-V Compliance Suite
#--------------------------------------------------------------------

SUITE_REPO = https://github.com/riscv/riscv-compliance
SUITE = $(realpath $(GRLIB)/software/noelv/riscv-compliance)
SUITE_LOCAL = $(GRLIB)/software/noelv/compliance
VARIANT = rv32i rv32im rv64i rv64im

update-riscv-compliance:
	if !(test -r "$(SUITE)/.git"); then \
	git clone -b master --depth=1 -n --recursive $(SUITE_REPO) $(SUITE); \
	cd $(SUITE); git checkout master; \
	fi; \
	cd $(SUITE); git pull origin master; git submodule update --init --recursive;

patch-riscv-compliance: $(SUITE_LOCAL)
	cp -rf $(SUITE_LOCAL)/noelv $(SUITE)/riscv-target
	cp -rf $(TESTS_LOCAL)/riscv_test.h $(SUITE)/riscv-test-env/p
	cp -rf $(SUITE_LOCAL)/compliance.ld $(SUITE)/riscv-test-env/p

install-riscv-compliance: update-riscv-compliance patch-riscv-compliance

#--------------------------------------------------------------------
# Build Compliance Suite
#--------------------------------------------------------------------

compliance-build: patch-riscv-compliance
	cd $(SUITE); make clean RISCV_TARGET=noelv;
	for var in $(VARIANT); do \
		cd $(SUITE); make RISCV_TARGET=noelv RISCV_DEVICE=rv$(XLEN)i RISCV_ISA=$$var variant; \
		mv $(SUITE)/work/$$var/* $(SUITE)/work; \
		rm -rf $(SUITE)/work/$$var; \
	done

#--------------------------------------------------------------------
# Install RISC-V ISA Simulator
#--------------------------------------------------------------------

SPIKE_REPO = https://github.com/riscv/riscv-isa-sim
SPIKE_LOCAL = $(GRLIB)/software/noelv/riscv-isa-sim

update-riscv-spike:
	if !(test -r "$(SPIKE_LOCAL)/.git"); then \
	git clone -b master --depth=1 -n --recursive $(SPIKE_REPO) $(SPIKE_LOCAL); \
	cd $(SPIKE_LOCAL); git checkout master; \
	fi; \
	cd $(SPIKE_LOCAL); git pull origin master; git submodule update --init --recursive;

install-riscv-spike: update-riscv-spike
	-rm -rf $(SPIKE_LOCAL)/build
	mkdir $(SPIKE_LOCAL)/build
	cd $(SPIKE_LOCAL)/build; ../configure --prefix=$(RTOOLCHAIN) --enable-commitlog
	cd $(SPIKE_LOCAL)/build; make; make install

#--------------------------------------------------------------------
# Install RISC-V Proxy Kernel
#--------------------------------------------------------------------

PK_REPO = https://github.com/riscv/riscv-pk
PK_LOCAL = $(GRLIB)/software/noelv/riscv-pk

update-riscv-pk:
	if !(test -r "$(PK_LOCAL)/.git"); then \
	git clone -b master --depth=1 -n --recursive $(PK_REPO) $(PK_LOCAL); \
	cd $(PK_LOCAL); git checkout master; \
	fi; \
	cd $(PK_LOCAL); git pull origin master; git submodule update --init --recursive;

patch-riscv-pk: $(TESTS_LOCAL)
	cp -rf $(TESTS_LOCAL)/bbl.lds $(PK_LOCAL)/bbl
	cp -rf $(TESTS_LOCAL)/encoding.h $(PK_LOCAL)/machine
	cp -rf $(TESTS_LOCAL)/uart/* $(PK_LOCAL)/machine
	cp -rf $(TESTS_LOCAL)/minit.c $(PK_LOCAL)/machine

install-riscv-pk: update-riscv-pk
	-rm -rf $(PK_LOCAL)/build
	mkdir $(PK_LOCAL)/build
	cd $(PK_LOCAL)/build; ../configure --prefix=$(RTOOLCHAIN) --host=riscv$(XLEN)-unknown-elf
	cd $(PK_LOCAL)/build; make; make install
	make patch-riscv-pk

#--------------------------------------------------------------------
# Zephyr Project
#--------------------------------------------------------------------

ZEPHYR_LOCAL = $(GRLIB)/software/noelv/zephyr/zephyr
ZEPHYR_SDK_X = $(GRLIB)/software/noelv/zephyr-sdk
ZEPHYR_SDK = $(realpath $(ZEPHYR_SDK_X))
ZEPHYR_SDK_VERSION = "0.10.3"

update-zephyr:
	if !(test -r "$(ZEPHYR_LOCAL)/.git"); then \
	west init $(ZEPHYR_LOCAL); \
	cd $(ZEPHYR_LOCAL); west update; \
	fi; \
	cd $(ZEPHYR_LOCAL); west update;
	if !(test -r "zephyr-sdk-$(ZEPHYR_SDK_VERSION)-setup.run"); then \
	wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v$(ZEPHYR_SDK_VERSION)/zephyr-sdk-$(ZEPHYR_SDK_VERSION)-setup.run .; \
	fi; \
	rm -rf $(ZEPHYR_SDK_X);
	mkdir $(ZEPHYR_SDK_X);
	chmod +x zephyr-sdk-$(ZEPHYR_SDK_VERSION)-setup.run;
	./zephyr-sdk-$(ZEPHYR_SDK_VERSION)-setup.run -- -d $(ZEPHYR_SDK);

patch-zephyr: $(TESTS_LOCAL)/zephyr
	cp -rf $(TESTS_LOCAL)/zephyr/boards/grlib-noelv $(ZEPHYR_LOCAL)/boards/riscv/
	cp -rf noelv.dts $(ZEPHYR_LOCAL)/boards/riscv/grlib-noelv/grlib-noelv.dts
	cp -rf $(TESTS_LOCAL)/zephyr/soc/grlib-noelv $(ZEPHYR_LOCAL)/soc/riscv/
	cp -rf $(TESTS_LOCAL)/zephyr/drivers/* $(ZEPHYR_LOCAL)/drivers/serial/

install-zephyr: update-zephyr patch-zephyr

#--------------------------------------------------------------------
# Dhrystone Benchmark
#--------------------------------------------------------------------

DHRYSTONE_LOCAL = $(GRLIB)/software/noelv/benchmark-dhrystone

-include $(DHRYSTONE_LOCAL)/Makefile

#--------------------------------------------------------------------
# Build Torture
#--------------------------------------------------------------------

torture.elf: $(TORTURE_LOCAL)/torture.S prom.ld $(TORTURE_LOCAL)/link.ld install-riscv-torture
	$(XCC) -I$(TORTURE)/env/p -T$(TORTURE_LOCAL)/link.ld $< -nostdlib -static -Wl,--no-gc-sections -march=$(RISCV_ARCH) -mabi=$(RISCV_ABI) -o $@

torture.srec: torture.elf
	$(OBJCOPY) $(OBJCOPY_OPTS) $(EXTRA_PROM) --remove-section=.riscv.attributes -O srec $< $@
	cp $@ ram.srec

#--------------------------------------------------------------------
# Torture Tests
#--------------------------------------------------------------------

gen-torture:
	cd $(TORTURE); make gen;
	cd $(TORTURE_LOCAL); rm -f torture.S; cp $(TORTURE)/output/test.S torture.S;
	cd $(TORTURE_LOCAL); sed -i 's/pseg_0:/.align 8\npseg_0:/g' torture.S;

sim-torture: gen-torture torture.srec

#--------------------------------------------------------------------
# Build RISCV-DV
#--------------------------------------------------------------------

%.dv.elf: %.dv
	$(XCC) -T$(TESTS_LOCAL)/link.ld $(DV)/build/$*.S -nostdlib -static -Wl,--no-gc-sections -march=$(RISCV_ARCH) -mabi=$(RISCV_ABI) -o $@

%.dv.srec: %.dv.elf
	$(OBJCOPY) $(OBJCOPY_OPTS) $(EXTRA_PROM) --remove-section=.riscv.attributes -O srec $*.dv.elf $@
	cp $@ ram.srec

%.dv:
	rm -f %.dv.elf %.dv.srec;
	cd $(DV); rm -rf out_*; rm -rf build; mkdir build;
	cd $(DV); export RISCV_TOOLCHAIN=$(RTOOLCHAIN) && ./run -test $* $(DV_OPTS);
	cd $(DV); mv out/asm_tests/$*.0.S build/$*.S;

#--------------------------------------------------------------------
# ISA Tests
#--------------------------------------------------------------------

%.isa: patch-riscv-tests       
	cd $(TESTS)/isa; make clean; make $* XLEN=$(XLEN);
	cp $(TESTS)/isa/$* $*.isa

SREC_DIR ?= .
%.isa.srec: %.isa
	$(OBJCOPY) $(OBJCOPY_OPTS) $(EXTRA_PROM) --remove-section=.riscv.attributes -O srec $< $(SREC_DIR)/$@
ifeq ("$(SREC_DIR)",".")
	cp $@ ram.srec
endif

#--------------------------------------------------------------------
# Benchmark Tests
#--------------------------------------------------------------------

%.bench: patch-riscv-tests        
	cd $(TESTS)/benchmarks; make clean; make $*.riscv XLEN=$(XLEN) UART=$(UART)
	cp $(TESTS)/benchmarks/$*.riscv $*.bench

%.bench.srec: %.bench
	$(OBJCOPY) $(OBJCOPY_OPTS) $(EXTRA_PROM) $(SECTIONS) -O srec $< $(SREC_DIR)/$@
ifeq ("$(SREC_DIR)", ".")
	cp $@ ram.srec
endif

#--------------------------------------------------------------------
# Build Templates
#--------------------------------------------------------------------

%.o: %.c
	$(XCC) $(XCFLAGS) $<

%.riscv: %.o
	$(LINK) $(LINK_OPTS) -o $@ $<

%.dtb: %.dts
	dtc -I dts $< -O dtb -o $@

%.elf: %.S prom.ld $(DTB)
	$(XCC) -march=$(RISCV_ARCH) -mabi=$(RISCV_ABI) -Tprom.ld $< -nostdlib -static -Wl,--no-gc-sections -o $@

prom.srec: prom.elf
	$(OBJCOPY) $(PROM_OPTS) $(EXTRA_PROM) --remove-section=.riscv.attributes -O srec $< $@

%.srec: %.riscv
	$(OBJCOPY) $(OBJCOPY_OPTS) $(EXTRA_PROM) -O srec $< $@

#--------------------------------------------------------------------
# Soft
#--------------------------------------------------------------------

ram.srec: systest.riscv
	$(OBJCOPY) -O srec $< ram.srec

soft: prom.srec ram.srec $(EXTRA_SOFT)

#--------------------------------------------------------------------
# BBL
#--------------------------------------------------------------------

bbl: patch-riscv-pk
	cd $(PK_LOCAL)/build; ../configure --prefix=$(RTOOLCHAIN) --host=riscv$(XLEN)-unknown-elf
	cd $(PK_LOCAL)/build; make; make bbl;
	cp $(PK_LOCAL)/build/$@ .

bbl.srec: bbl
	$(OBJCOPY) $(OBJCOPY_OPTS) $(EXTRA_PROM) $(SECTIONS) -O srec $< ram.srec

#--------------------------------------------------------------------
# Zephyr Project
#--------------------------------------------------------------------

ZEPHYR_BOARD = noelv

%.zephyr: patch-zephyr
	rm -rf $(ZEPHYR_LOCAL)/build;
	source $(ZEPHYR_LOCAL)/zephyr-env.sh;
	cd $(ZEPHYR_LOCAL); export ZEPHYR_SDK_INSTALL_DIR=$(ZEPHYR_SDK) && export ZEPHYR_TOOLCHAIN_VARIANT=zephyr && west build -b $(ZEPHYR_BOARD) samples/$*;
	cp $(ZEPHYR_LOCAL)/build/zephyr/zephyr.elf $@

%.zephyr.srec: %.zephyr
	$(OBJCOPY) $(OBJCOPY_OPTS) $(EXTRA_PROM) $(SECTIONS) -O srec $< ram.srec

#--------------------------------------------------------------------
# Clean Up
#--------------------------------------------------------------------

CLEAN += 

tests-clean:
	cd $(TESTS)/benchmarks; make clean; rm -rf *.riscv

soft-clean:
	-rm -rf *.o *.riscv *.a *.elf

clean-riscv-tests:
	-rm -rf $(TESTS)

