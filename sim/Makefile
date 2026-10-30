# David_Harris@hmc.edu 15 July 2024
# Simulation  Makefile for CORE-V-Wally
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

SIM = ${WALLY}/sim
TESTS = ${WALLY}/tests

.PHONY: all coveragetests deriv clean benchmarks

all: coveragetests deriv

coveragetests:
	$(MAKE) -C ${TESTS}/coverage64gc
	$(MAKE) -C ${TESTS}/coverage32gc
	$(MAKE) -C ${TESTS}/coverage32imc

deriv:
	derivgen.pl

.PHONY: QuestaFunctCoverage QuestaCodeCoverage

# Merge the per-test functional coverage databases written by wsim --fcov and report the total.
QuestaFunctCoverage:
	mkdir -p questa/fcov
	vcover merge -out questa/fcov_ucdb/fcov.ucdb questa/fcov_ucdb/rv64gc*.ucdb -suppress 6854 -64
	vcover report questa/fcov_ucdb/fcov.ucdb -details -cvg > questa/fcov/fcov.log
	vcover report questa/fcov_ucdb/fcov.ucdb -cvg > questa/fcov/fcov.summary.log
	vcover report questa/fcov_ucdb/fcov.ucdb -details -cvg -below 100 > questa/fcov/fcov.uncovered.log
	grep -E "TOTAL COVERGROUP COVERAGE" questa/fcov/fcov.summary.log

# Merge the per-test code coverage databases written by wsim --ccov for CONFIG (rv64gc, rv32gc or rv32imc), apply
# that configuration's exclusions (questa/coverage-exclusions-$(CONFIG).do) to the merged database, and write the
# reports (questa/cov/$(CONFIG)_*.rpt) and the HTML report (covhtmlreport/$(CONFIG)).  The per-test databases carry
# no exclusions, so editing the exclusions needs only this target rerun, not the simulations.  The exclusion step
# fails if any exclusion names a scope, line or row that does not exist, so stale exclusions do not go unnoticed.
CONFIG ?= rv64gc
COVUCDB = questa/cov/$(CONFIG)_cov.ucdb
COVUNITS = ebu priv ifu lsu fpu ieu hzu

QuestaCodeCoverage:
	mkdir -p questa/cov
	vcover merge -out questa/cov/$(CONFIG)_merged.ucdb questa/ucdb/$(CONFIG)_*.ucdb -logfile questa/cov/$(CONFIG)_merge.log
	vsim -c -viewcov questa/cov/$(CONFIG)_merged.ucdb -l questa/cov/$(CONFIG)_exclusions.log \
	  -do "onerror {quit -code 1 -f}; do questa/coverage-exclusions-$(CONFIG).do; coverage save $(COVUCDB); quit -f" > /dev/null
	@if grep -E "vish-4014|no matching coverage data was found|\*\* Error" questa/cov/$(CONFIG)_exclusions.log; then \
	  echo "coverage-exclusions-$(CONFIG).do: an exclusion matched nothing (see questa/cov/$(CONFIG)_exclusions.log)"; exit 1; fi
	vcover report -details $(COVUCDB) > questa/cov/$(CONFIG)_coverage_details.rpt
	for u in $(COVUNITS); do \
	  vcover report $(COVUCDB) -details -instance=/core/$$u. > questa/cov/$(CONFIG)_coverage_$$u.rpt; \
	  vcover report $(COVUCDB) -below 100 -details -instance=/core/$$u. > questa/cov/$(CONFIG)_uncovered_$$u.rpt; \
	done
	vcover report -hierarchical $(COVUCDB) > questa/cov/$(CONFIG)_coverage_hierarchical.rpt
	vcover report -below 100 -hierarchical $(COVUCDB) > questa/cov/$(CONFIG)_uncovered_hierarchical.rpt
	vcover report -details -threshH 100 -html -output covhtmlreport/$(CONFIG) $(COVUCDB)

benchmarks:
	$(MAKE) -C ${WALLY}benchmarks/embench build
	$(MAKE) -C ${WALLY}/benchmarks/embench size
	$(MAKE) -C ${WALLY}/benchmarks/embench modelsim_build_memfile
	$(MAKE) -C ${WALLY}/benchmarks/coremark

clean:
