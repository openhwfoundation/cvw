.SECONDEXPANSION:

MAKEFLAGS += --output-sync --no-print-directory
nproc := $(shell nproc --ignore=1)

# Directories
arch_dir := $(WALLY)/addins/riscv-arch-test
wally_dir := $(WALLY)/tests/wally-riscv-arch-test
work_dir := ./riscof_work
work := ./work
arch_workdir := $(work)/riscv-arch-test
wally_workdir := $(work)/wally-riscv-arch-test
current_dir := $(shell pwd)

# General make rules
.PHONY: all riscv-arch-test wally-riscv-arch-test clean
all: riscv-arch-test wally-riscv-arch-test
riscv-arch-test: arch32e arch32 arch64

wally-riscv-arch-test: wally32 wally64

# Generate config.ini files
config%.ini: config.ini
	sed 's,{0},$(current_dir),g;s,{1},$(patsubst %64,%64gc,$(patsubst %32,%32gc,$*)),g;s,{2},$(nproc),g' config.ini > $@

# Generate riscv-arch-test targets
arch%: config$$*.ini | $(work_dir) $(arch_workdir)
	uv run riscof run --work-dir=$(work_dir)/$@ --config=$< --suite=$(arch_dir)/riscv-test-suite/ --env=$(arch_dir)/riscv-test-suite/env --no-browser
	$(MAKE) -f makefile-memfile WORKDIR=$(work_dir)/$@ BITWIDTH=$(patsubst %32e,%32,$*)
	rsync -a $(work_dir)/$@/rv*/* $(arch_workdir)/rv$(patsubst %64,%64i,$(patsubst %32,%32i,$*))_m || echo "error suppressed"

# Generate wally-riscv-arch-test targets
wally%: config$$*.ini | $(work_dir) $(wally_workdir)
	uv run riscof run --work-dir=$(work_dir)/$@ --config=$< --suite=$(wally_dir)/riscv-test-suite/ --env=$(wally_dir)/riscv-test-suite/env --no-browser --no-dut-run
	$(MAKE) -f makefile-memfile WORKDIR=$(work_dir)/$@
	rsync -a $(work_dir)/$@/rv*/* $(wally_workdir)/rv$(patsubst %64,%64i,$(patsubst %32,%32i,$*))_m || echo "error suppressed"

clean:
	rm -f config??*.ini
	rm -rf $(work_dir)
	rm -rf $(wally_workdir)
	rm -rf $(arch_workdir)

$(work_dir) $(arch_workdir) $(wally_workdir):
	mkdir -p $@
