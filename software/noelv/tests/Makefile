#=======================================================================
# UCB VLSI FLOW: Makefile for riscv-bmarks
#-----------------------------------------------------------------------
# Yunsup Lee (yunsup@cs.berkeley.edu)
#

XLEN ?= 64
UART ?= 1

default: all

src_dir = .

instname = riscv-bmarks
instbasedir = $(UCB_VLSI_HOME)/install

#--------------------------------------------------------------------
# Sources
#--------------------------------------------------------------------

bmarks = \
	median \
	qsort \
	rsort \
	towers \
	vvadd \
	multiply \
	mm \
	dhrystone \
	spmv \
	mt-vvadd \
	mt-matmul \
	pmp \
	float \
	coremark \
	primes \

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

ifeq ($(XLEN), 64)
  RISCV_ABI       ?= lp64d
else
  RISCV_ABI       ?= ilp32d
endif
RISCV_ARCH ?= rv$(XLEN)im
RISCV_PREFIX ?= riscv$(XLEN)-unknown-elf-
#RISCV_PREFIX ?= riscv$(XLEN)-gaisler-elf-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
RISCV_GCC_OPTS ?= -DPREALLOCATE=1 -mcmodel=medany -static -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf -march=$(RISCV_ARCH) -mabi=$(RISCV_ABI) -DNO_UART_WAIT=$(UART) -DNOSTAT
#RISCV_GCC_OPTS ?= -DPREALLOCATE=1 -mcmodel=medany -static -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf -march=rv$(XLEN)im -mabi=$(RISCV_ABI) -DNO_UART_WAIT=$(UART) -fgcse-after-reload -fpredictive-commoning -mtune=sifive-7-series -fipa-cp-clone -falign-loops=8 -falign-jumps=8 
RISCV_LINK ?= $(RISCV_GCC) -T $(src_dir)/common/test.ld $(incs)
#RISCV_LINK_OPTS ?= -static -nostdlib -nostartfiles -lm -lgcc -T $(src_dir)/common/noelv.ld
RISCV_LINK_OPTS ?= -static -nostartfiles -lm -lgcc -T $(src_dir)/common/noelv.ld
RISCV_OBJDUMP ?= $(RISCV_PREFIX)objdump --disassemble-all --disassemble-zeroes --section=.text --section=.text.startup --section=.data
RISCV_SIM ?= spike --isa=rv$(XLEN)gc

incs  += -I$(src_dir)/../uart -I$(src_dir)/../env -I$(src_dir)/common $(addprefix -I$(src_dir)/, $(bmarks))
objs  :=

#--
# Bench Extra Build Rules
#--

coremark.riscv: EXTRA_GCC_OPTS := -DFLAGS_STR=\""$(RISCV_GCC_OPTS)"\" -DITERATIONS=1 -DPERFORMANCE_RUN=1 -finline-functions -falign-jumps=8 -falign-functions=8 -falign-loops=8 -funroll-all-loops --param max-inline-insns-auto=20 -funswitch-loops -fgcse-after-reload -fpredictive-commoning -fipa-cp-clone --param inline-min-speedup=10

dhrystone.riscv: EXTRA_GCC_OPTS := -mexplicit-relocs -O3 -Wno-implicit -falign-functions=8 -falign-loops=8 -falign-jumps=8 -funroll-all-loops -funswitch-loops -fgcse-after-reload -fpredictive-commoning

define compile_template
$(1).riscv: $(wildcard $(src_dir)/$(1)/*) $(wildcard $(src_dir)/common/*) $(wildcard $(src_dir)/../uart/*)
	$$(RISCV_GCC) $$(incs) $$(RISCV_GCC_OPTS) $$(EXTRA_GCC_OPTS) -o $$@ $(wildcard $(src_dir)/$(1)/*.c) $(wildcard $(src_dir)/$(1)/*.S) $(wildcard $(src_dir)/common/*.c) $(wildcard $(src_dir)/../uart/*.c) $(wildcard $(src_dir)/common/*.S) $$(RISCV_LINK_OPTS)
endef

$(foreach bmark,$(bmarks),$(eval $(call compile_template,$(bmark))))

#------------------------------------------------------------
# Build and run benchmarks on riscv simulator

bmarks_riscv_bin  = $(addsuffix .riscv,  $(bmarks))
bmarks_riscv_dump = $(addsuffix .riscv.dump, $(bmarks))
bmarks_riscv_out  = $(addsuffix .riscv.out,  $(bmarks))

$(bmarks_riscv_dump): %.riscv.dump: %.riscv
	$(RISCV_OBJDUMP) $< > $@

$(bmarks_riscv_out): %.riscv.out: %.riscv
	$(RISCV_SIM) $< > $@

riscv: $(bmarks_riscv_dump)
run: $(bmarks_riscv_out)

junk += $(bmarks_riscv_bin) $(bmarks_riscv_dump) $(bmarks_riscv_hex) $(bmarks_riscv_out)

#------------------------------------------------------------
# Default

all: riscv

#------------------------------------------------------------
# Install

date_suffix = $(shell date +%Y-%m-%d_%H-%M)
install_dir = $(instbasedir)/$(instname)-$(date_suffix)
latest_install = $(shell ls -1 -d $(instbasedir)/$(instname)* | tail -n 1)

install:
	mkdir $(install_dir)
	cp -r $(bmarks_riscv_bin) $(bmarks_riscv_dump) $(install_dir)

install-link:
	rm -rf $(instbasedir)/$(instname)
	ln -s $(latest_install) $(instbasedir)/$(instname)

#------------------------------------------------------------
# Clean up

clean:
	rm -rf $(objs) $(junk)
