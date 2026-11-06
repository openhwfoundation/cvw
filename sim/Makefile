# David_Harris@hmc.edu 15 July 2024
# Simulation  Makefile for CORE-V-Wally
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

SIM = ${WALLY}/sim
TESTS = ${WALLY}/tests

.PHONY: all coveragetests deriv clean benchmarks

all: coveragetests deriv

coveragetests:
	$(MAKE) -C ${TESTS}/coverage

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

# Merge the per-test code coverage databases written by wsim --ccov, apply the rv64gc exclusions to the merged
# database, and write the reports.  The per-test databases carry no exclusions, so editing
# coverage-exclusions-rv64gc.do needs only this target rerun, not the simulations.  The exclusion step fails if
# any exclusion names a scope, line or row that does not exist, so stale exclusions do not go unnoticed.
QuestaCodeCoverage:
	mkdir -p questa/cov
	vcover merge -out questa/cov/merged.ucdb questa/ucdb/rv64gc*.ucdb -logfile questa/cov/log
	vsim -c -viewcov questa/cov/merged.ucdb -l questa/cov/exclusions.log \
	  -do "onerror {quit -code 1 -f}; do questa/coverage-exclusions-rv64gc.do; coverage save questa/ucdb/cov.ucdb; quit -f" > /dev/null
	@if grep -E "vish-4014|no matching coverage data was found|\*\* Error" questa/cov/exclusions.log; then \
	  echo "coverage-exclusions-rv64gc.do: an exclusion matched nothing (see questa/cov/exclusions.log)"; exit 1; fi
#	vcover merge -out questa/ucdb/cov.ucdb questa/ucdb/rv64gc_arch64i.ucdb questa/ucdb/rv64gc*.ucdb questa/ucdb/buildroot_buildroot.ucdb riscv.ucdb -logfile questa/cov/log
	vcover report -details questa/ucdb/cov.ucdb > questa/cov/rv64gc_coverage_details.rpt
	vcover report questa/ucdb/cov.ucdb -details -instance=/core/ebu. > questa/cov/rv64gc_coverage_ebu.rpt
	vcover report questa/ucdb/cov.ucdb -details -instance=/core/priv. > questa/cov/rv64gc_coverage_priv.rpt
	vcover report questa/ucdb/cov.ucdb -details -instance=/core/ifu. > questa/cov/rv64gc_coverage_ifu.rpt
	vcover report questa/ucdb/cov.ucdb -details -instance=/core/lsu. > questa/cov/rv64gc_coverage_lsu.rpt
	vcover report questa/ucdb/cov.ucdb -details -instance=/core/fpu. > questa/cov/rv64gc_coverage_fpu.rpt
	vcover report questa/ucdb/cov.ucdb -details -instance=/core/ieu. > questa/cov/rv64gc_coverage_ieu.rpt
	vcover report questa/ucdb/cov.ucdb -details -instance=/core/hzu. > questa/cov/rv64gc_coverage_hzu.rpt
	vcover report questa/ucdb/cov.ucdb -below 100 -details -instance=/core/ebu. > questa/cov/rv64gc_uncovered_ebu.rpt
	vcover report questa/ucdb/cov.ucdb -below 100 -details -instance=/core/priv. > questa/cov/rv64gc_uncovered_priv.rpt
	vcover report questa/ucdb/cov.ucdb -below 100 -details -instance=/core/ifu. > questa/cov/rv64gc_uncovered_ifu.rpt
	vcover report questa/ucdb/cov.ucdb -below 100 -details -instance=/core/lsu. > questa/cov/rv64gc_uncovered_lsu.rpt
	vcover report questa/ucdb/cov.ucdb -below 100 -details -instance=/core/fpu. > questa/cov/rv64gc_uncovered_fpu.rpt
	vcover report questa/ucdb/cov.ucdb -below 100 -details -instance=/core/ieu. > questa/cov/rv64gc_uncovered_ieu.rpt
	vcover report questa/ucdb/cov.ucdb -below 100 -details -instance=/core/hzu. > questa/cov/rv64gc_uncovered_hzu.rpt
	vcover report -hierarchical questa/ucdb/cov.ucdb > questa/cov/rv64gc_coverage_hierarchical.rpt
	vcover report -below 100 -hierarchical questa/ucdb/cov.ucdb > questa/cov/rv64gc_uncovered_hierarchical.rpt
#	vcover report -below 100 questa/ucdb/cov.ucdb > questa/cov/rv64gc_coverage.rpt
#	vcover report -recursive questa/ucdb/cov.ucdb > questa/cov/rv64gc_recursive.rpt
	vcover report -details -threshH 100 -html questa/ucdb/cov.ucdb

benchmarks:
	$(MAKE) -C ${WALLY}benchmarks/embench build
	$(MAKE) -C ${WALLY}/benchmarks/embench size
	$(MAKE) -C ${WALLY}/benchmarks/embench modelsim_build_memfile
	$(MAKE) -C ${WALLY}/benchmarks/coremark

clean:
