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

.PHONY: QuestaFunctCoverage VerilatorFunctCoverage QuestaCodeCoverage VcsFunctCoverage VcsCodeCoverage

# Merge the per-test functional coverage databases written by wsim --fcov and report the total.
QuestaFunctCoverage:
	mkdir -p questa/fcov
	vcover merge -out questa/fcov_ucdb/fcov.ucdb questa/fcov_ucdb/rv64gc*.ucdb -suppress 6854 -64
	vcover report questa/fcov_ucdb/fcov.ucdb -details -cvg > questa/fcov/fcov.log
	vcover report questa/fcov_ucdb/fcov.ucdb -cvg > questa/fcov/fcov.summary.log
	vcover report questa/fcov_ucdb/fcov.ucdb -details -cvg -below 100 > questa/fcov/fcov.uncovered.log
	grep -E "TOTAL COVERGROUP COVERAGE" questa/fcov/fcov.summary.log

# The same for wsim --fcov --sim verilator
VerilatorFunctCoverage:
	mkdir -p verilator/fcov
	verilator_coverage --write verilator/fcov/fcov.dat verilator/fcov_dat/rv64gc*.dat
	verilator_coverage --report hier verilator/fcov/fcov.dat > verilator/fcov/fcov.log
	verilator_coverage --report summary verilator/fcov/fcov.dat > verilator/fcov/fcov.summary.log
	grep -v "100.0%" verilator/fcov/fcov.log > verilator/fcov/fcov.uncovered.log
	grep -E "covergroup" verilator/fcov/fcov.summary.log

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

# VCS counterparts of the two targets above, for wsim --sim vcs --ccov/--fcov and regression-wally
# --coveragesim vcs.  Each simulation writes its own coverage database, a .vdb directory, which urg merges.
# The code coverage exclusions of CONFIG are those of questa/coverage-exclusions-$(CONFIG).do and the RTL's
# "// coverage off" pragmas, translated by vcs/exclusions2el into a URG exclusion file for the merged
# database; vcs/cov/exclusions-$(CONFIG).log says what each exclusion became, or why VCS has no counterpart.
# Reports: vcs/cov/$(CONFIG)_coverage_hierarchical.rpt (per-instance summary), and in vcs/cov/$(CONFIG):
# report (details, text and HTML), uncovered (details of what is not covered) and unexcluded (no exclusions).
URG = urg -full64
VCSCOV = vcs/cov/$(CONFIG)

VcsFunctCoverage:
	rm -rf vcs/fcov && mkdir -p vcs/fcov
	ls -d $(CURDIR)/vcs/fcov_ucdb/rv64gc*.vdb > vcs/fcov/vdbs.txt
	cd vcs/fcov && $(URG) -f vdbs.txt -dbname fcov -format text -report report -log urg.log > /dev/null 2>&1
	cd vcs/fcov && $(URG) -dir fcov.vdb -format text -show brief -report uncovered -log uncovered.log > /dev/null 2>&1
	cp vcs/fcov/report/groups.txt vcs/fcov/fcov.summary.log
	@echo "VCS TOTAL COVERGROUP COVERAGE: $$(grep -A2 '^Total Groups Coverage Summary' vcs/fcov/report/groups.txt | tail -n 1 | awk '{print $$1}')%"

# urg names a merged database after -dbname in the current directory (a / in the name separates a test name),
# so the merges run in vcs/cov/$(CONFIG) and vcs/fcov
VcsCodeCoverage:
	rm -rf $(VCSCOV) && mkdir -p $(VCSCOV)
	ls -d $(CURDIR)/vcs/ucdb/$(CONFIG)_*.vdb > $(VCSCOV)/vdbs.txt
	cd $(VCSCOV) && $(URG) -f vdbs.txt -dbname merged -noreport -log merge.log > /dev/null 2>&1
	cd $(VCSCOV) && $(URG) -dir merged.vdb -dump full_exclusions -format text -show ratios -report unexcluded -log unexcluded.log > /dev/null 2>&1
	vcs/exclusions2el --wally $(WALLY) --do questa/coverage-exclusions-$(CONFIG).do --dump $(VCSCOV) \
	  --modinfo $(VCSCOV)/unexcluded/modinfo.txt --out vcs/cov/exclusions-$(CONFIG).el --log vcs/cov/exclusions-$(CONFIG).log
	cd $(VCSCOV) && $(URG) -dir merged.vdb -elfile ../exclusions-$(CONFIG).el -format both -show ratios -report report -log report.log > /dev/null 2>&1
	cd $(VCSCOV) && $(URG) -dir merged.vdb -elfile ../exclusions-$(CONFIG).el -format text -show brief -report uncovered -log uncovered.log > /dev/null 2>&1
	cp $(VCSCOV)/report/hierarchy.txt vcs/cov/$(CONFIG)_coverage_hierarchical.rpt
	cp $(VCSCOV)/unexcluded/hierarchy.txt vcs/cov/$(CONFIG)_coverage_hierarchical_unexcluded.rpt
	@grep -A2 "^Total Coverage Summary" $(VCSCOV)/report/dashboard.txt
	@grep "^Warning" vcs/cov/exclusions-$(CONFIG).log || true

benchmarks:
	$(MAKE) -C ${WALLY}benchmarks/embench build
	$(MAKE) -C ${WALLY}/benchmarks/embench size
	$(MAKE) -C ${WALLY}/benchmarks/embench modelsim_build_memfile
	$(MAKE) -C ${WALLY}/benchmarks/coremark

clean:
