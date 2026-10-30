# Makefile added 1/20/22 David_Harris@hmc.edu
# Expanded and developed by Daniel Torres dtorres@hmc.edu
# Compile Embench for Wally

embench_dir = ../../addins/embench-iot

# Builds for RV32 by default; make run XLEN=64 builds for RV64 and simulates rv64gc.
# ARCH, ABI, and CONFIG can also be overridden, e.g. make run ARCH=rv32imc_zicsr CONFIG=rv32imc
XLEN = 32
ifeq ($(XLEN),64)
ARCH = rv64imac_zicsr
ABI = lp64
CONFIG = rv64gc
# RAM is at 0x80000000, beyond the reach of medlow on RV64, so the toolchain's libraries
# must also be built medany (bin/installation/riscv-gnu-toolchain-install.sh)
XLENFLAGS = -mcmodel=medany
# the board's linker script specifies elf32
XLENLDFLAGS = -Wl,--oformat=elf64-littleriscv
else
ARCH = rv32imac_zicsr
ABI = ilp32
CONFIG = rv32gc
endif
SIGGRANULARITY = $(shell echo $$(($(XLEN)/8)))

# XLEN-independent startup code, in place of the board's startup/crt0.S
CRT0 = $(CURDIR)/crt0.S
MFLAGS = -march=$(ARCH) -mabi=$(ABI) $(XLENFLAGS)

all: build
run: build size sim

allClean: clean all

build: buildspeed buildsize
buildspeed: build_speedopt_speed build_sizeopt_speed
buildsize: build_speedopt_size build_sizeopt_size

# uses the build_all.py python file to build the tests in addins/embench-iot/bd_speed/ optimized for speed and size
build_speedopt_speed:
	$(embench_dir)/build_all.py --builddir=bd_speedopt_speed --arch riscv32 --chip generic --board rv32wallyverilog --ldflags="-nostartfiles $(CRT0) $(MFLAGS) $(XLENLDFLAGS)" --cflags="-O2 -nostartfiles $(MFLAGS) -std=gnu17"
	# remove files not used in embench1.0  When changing to 2.0, restore these files
	#rm -rf $(embench_dir)/bd_speedopt_speed/src/md5sum
	#rm -rf $(embench_dir)/bd_speedopt_speed/src/tarfind
	#rm -rf $(embench_dir)/bd_speedopt_speed/src/primecount
	find $(embench_dir)/bd_speedopt_speed/ -type f ! -name "*.*" | while read f; do cp "$$f" "$$f.elf"; done

build_sizeopt_speed:
	$(embench_dir)/build_all.py --builddir=bd_sizeopt_speed --arch riscv32 --chip generic --board rv32wallyverilog --ldflags="-nostartfiles $(CRT0) $(MFLAGS) $(XLENLDFLAGS)" --cflags="-Os -nostartfiles $(MFLAGS) -std=gnu17"
	# remove files not used in embench1.0  When changing to 2.0, restore these files
	#rm -rf $(embench_dir)/bd_sizeopt_speed/src/md5sum
	#rm -rf $(embench_dir)/bd_sizeopt_speed/src/tarfind
	#rm -rf $(embench_dir)/bd_sizeopt_speed/src/primecount
	find $(embench_dir)/bd_sizeopt_speed/ -type f ! -name "*.*" | while read f; do cp "$$f" "$$f.elf"; done

# uses the build_all.py python file to build the tests in addins/embench-iot/bd_speed/ optimized for speed and size
build_speedopt_size:
	$(embench_dir)/build_all.py --builddir=bd_speedopt_size --arch riscv32 --chip generic --board rv32wallyverilog --ldflags="-nostdlib -nostartfiles ../../../config/riscv32/boards/rv32wallyverilog/startup/dummy.S $(MFLAGS) $(XLENLDFLAGS)" --cflags="-O2 -msave-restore $(MFLAGS) -std=gnu17" --dummy-libs="libgcc libm libc crt0"

build_sizeopt_size:
	$(embench_dir)/build_all.py --builddir=bd_sizeopt_size --arch riscv32 --chip generic --board rv32wallyverilog --ldflags="-nostdlib -nostartfiles ../../../config/riscv32/boards/rv32wallyverilog/startup/dummy.S $(MFLAGS) $(XLENLDFLAGS)" --cflags="-Os -msave-restore $(MFLAGS) -std=gnu17" --dummy-libs="libgcc libm libc crt0"

# builds dependencies, then launches sim and finally runs python wrapper script to present results
sim: sim_build_memfile sim_run speed

# launches sim to simulate tests on wally
# speed reports both builds; simulate them in parallel, as each takes about half an hour
sim_run:
	wsim --sim verilator $(CONFIG) $(embench_dir)/bd_speedopt_speed/src --test embench --name embench_speedopt --params "BPRED_LOGGER=1\'b1" & speedopt=$$!; \
	wsim --sim verilator $(CONFIG) $(embench_dir)/bd_sizeopt_speed/src --test embench --name embench_sizeopt --params "BPRED_LOGGER=1\'b1" & sizeopt=$$!; \
	wait $$speedopt && wait $$sizeopt

# builds the objdump based on the compiled c elf files
objdump:
	find $(embench_dir)/bd_*_speed/ -type f -name "*.elf" | while read f; do riscv64-unknown-elf-objdump -S -D "$$f" > "$$f.objdump"; done

# build memfiles
sim_build_memfile: objdump
	find $(embench_dir)/bd_*_speed/ -type f -name "*.elf" | while read f; do elf2hex "$$f" "$$f.memfile"; done

# builds the tests for speed, runs them on spike and then launches python script to present results
# note that the speed python script benchmark_speed.py can get confused if there's both a .output file created from spike and questa
# you'll need to manually remove one of the two .output files, or run make clean
spike: buildspeed spike_run speed

# command to run spike on all of the benchmarks
spike_run:
	find $(embench_dir)/bd_*opt_speed/ -type f -name "*.elf" | while read f; do spike --isa=$(ARCH) +signature=$$f.spike.output +signature-granularity=$(SIGGRANULARITY) $$f; done

# creates the directory to store the results of the embench tests
actual_embench_results:
	mkdir -p actual_embench_results

# python wrapper to present results of embench size benchmark
size: actual_embench_results buildsize
	$(embench_dir)/benchmark_size.py --builddir=bd_speedopt_size --json-output > actual_embench_results/wallySpeedOpt_size.json
	$(embench_dir)/benchmark_size.py --builddir=bd_sizeopt_size --json-output > actual_embench_results/wallySizeOpt_size.json

# python wrapper to present results of embench speed benchmark
speed: actual_embench_results
	$(embench_dir)/benchmark_speed.py --builddir=bd_sizeopt_speed --target-module run_wally --cpu-mhz=1 --json-output > actual_embench_results/wallySizeOpt_speed.json
	$(embench_dir)/benchmark_speed.py --builddir=bd_speedopt_speed --target-module run_wally --cpu-mhz=1 --json-output > actual_embench_results/wallySpeedOpt_speed.json

# deletes all files
clean:
	rm -rf $(embench_dir)/bd_*_speed/
	rm -rf $(embench_dir)/bd_*_size/

allclean: clean
	rm -rf $(embench_dir)/logs/

# riscv64-unknown-elf-gcc -O2 -g -nostartfiles -I/home/harris/riscv-wally/addins/embench-iot/support -I/home/harris/riscv-wally/addins/embench-iot/config/riscv32/boards/ri5cyverilator -I/home/harris/riscv-wally/addins/embench-iot/config/riscv32/chips/generic -I/home/harris/riscv-wally/addins/embench-iot/config/riscv32 -DCPU_MHZ=1 -DWARMUP_HEAT=1 -o main.o /home/harris/riscv-wally/addins/embench-iot/support/main.c
