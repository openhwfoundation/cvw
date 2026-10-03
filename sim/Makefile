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



.PHONY: QuestaFunctCoverage QuestaCodeCoverage VcsFunctCoverage VcsCodeCoverage collect_functcov combine_functcov remove_functcov_artifacts riscvdv riscvdv_functcov

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

# VCS counterparts of the two targets above, for wsim --sim vcs --ccov/--fcov and regression-wally
# --coveragesim vcs.  Each simulation writes its own coverage database, a .vdb directory, which urg merges.
# The rv64gc code coverage exclusions are those of coverage-exclusions-rv64gc.do and the RTL's
# "// coverage off" pragmas, translated by vcs/exclusions2el into a URG exclusion file for the merged
# database; vcs/cov/exclusions-rv64gc.log says what each exclusion became, or why VCS has no counterpart.
# Reports: vcs/cov/rv64gc_coverage_hierarchical.rpt (per-instance summary), vcs/cov/report (details,
# text and HTML), vcs/cov/uncovered (details of what is not covered) and vcs/cov/unexcluded (no exclusions).
URG = urg -full64

VcsFunctCoverage:
	rm -rf vcs/fcov && mkdir -p vcs/fcov
	ls -d $(CURDIR)/vcs/fcov_ucdb/rv64gc*.vdb > vcs/fcov/vdbs.txt
	cd vcs/fcov && $(URG) -f vdbs.txt -dbname fcov -format text -report report -log urg.log > /dev/null 2>&1
	cd vcs/fcov && $(URG) -dir fcov.vdb -format text -show brief -report uncovered -log uncovered.log > /dev/null 2>&1
	cp vcs/fcov/report/groups.txt vcs/fcov/fcov.summary.log
	@echo "VCS TOTAL COVERGROUP COVERAGE: $$(grep -A2 '^Total Groups Coverage Summary' vcs/fcov/report/groups.txt | tail -n 1 | awk '{print $$1}')%"

# urg names a merged database after -dbname in the current directory (a / in the name separates a test name),
# so the merges run in vcs/cov and vcs/fcov
VcsCodeCoverage:
	rm -rf vcs/cov && mkdir -p vcs/cov
	ls -d $(CURDIR)/vcs/ucdb/rv64gc*.vdb > vcs/cov/vdbs.txt
	cd vcs/cov && $(URG) -f vdbs.txt -dbname merged -noreport -log merge.log > /dev/null 2>&1
	cd vcs/cov && $(URG) -dir merged.vdb -dump full_exclusions -format text -show ratios -report unexcluded -log unexcluded.log > /dev/null 2>&1
	vcs/exclusions2el --wally $(WALLY) --do questa/coverage-exclusions-rv64gc.do --dump vcs/cov \
	  --modinfo vcs/cov/unexcluded/modinfo.txt --out vcs/cov/exclusions-rv64gc.el --log vcs/cov/exclusions-rv64gc.log
	cd vcs/cov && $(URG) -dir merged.vdb -elfile exclusions-rv64gc.el -format both -show ratios -report report -log report.log > /dev/null 2>&1
	cd vcs/cov && $(URG) -dir merged.vdb -elfile exclusions-rv64gc.el -format text -show brief -report uncovered -log uncovered.log > /dev/null 2>&1
	cp vcs/cov/report/hierarchy.txt vcs/cov/rv64gc_coverage_hierarchical.rpt
	cp vcs/cov/unexcluded/hierarchy.txt vcs/cov/rv64gc_coverage_hierarchical_unexcluded.rpt
	@grep -A2 "^Total Coverage Summary" vcs/cov/report/dashboard.txt

collect_functcov: remove_functcov_artifacts riscvdv_functcov combine_functcov

riscvdv_functcov:
	mkdir -p ${SIM}/questa/fcov_logs
	mkdir -p ${SIM}/questa/fcov_ucdb
	rm -rf ${SIM}/questa/fcov_logs/*
	rm -rf ${SIM}/questa/fcov_ucdb/*
	$(MAKE) riscvdv test_name=riscv_arithmetic_basic_test				    >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_amo_test						          	>> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_ebreak_debug_mode_test			    >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_ebreak_test						          >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_floating_point_arithmetic_test	>> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_floating_point_mmu_stress_test	>> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_floating_point_rand_test			  >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_full_interrupt_test			      	>> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_hint_instr_test					        >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_illegal_instr_test			      	>> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_invalid_csr_test				       	>> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_jump_stress_test				      	>> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_loop_test							          >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_machine_mode_rand_test			    >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_mmu_stress_test					        >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_no_fence_test						        >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_non_compressed_instr_test			  >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_pmp_test							          >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_privileged_mode_rand_test			  >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_rand_instr_test					        >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_rand_jump_test					        >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_sfence_exception_test				    >> ${SIM}/questa/fcov.log 2>&1
	$(MAKE) riscvdv test_name=riscv_unaligned_load_store_test			  >> ${SIM}/questa/fcov.log 2>&1

riscvdv:
	python3 ${WALLY}/addins/riscv-dv/run.py --test ${test_name} --target rv64gc --output tests/riscvdv  --iterations 1 -si questa --iss spike --verbose --cov --seed 0 --steps gen,gcc_compile			>> ${SIM}/questa/fcov_logs/${test_name}.log 2>&1
#	python3 ${WALLY}/addins/riscv-dv/run.py --test ${test_name} --target rv64gc --output tests/riscvdv  --iterations 1 -si questa --iss spike --verbose --cov --seed 0 --steps gcc_compile	>> ${SIM}/questa/fcov_logs/${test_name}.log 2>&1
#	python3 ${WALLY}/addins/riscv-dv/run.py --test ${test_name} --target rv64gc --output tests/riscvdv  --iterations 1 -si questa --iss spike --verbose --cov --seed 0 --steps iss_sim		>> ${SIM}/questa/fcov_logs/${test_name}.log 2>&1
#	run-elf.bash --seed ${SIM}/questa/seed0.txt --verbose --elf ${WALLY}/tests/riscvdv/asm_test/${test_name}_0.o													>> ${SIM}/questa/fcov_logs/${test_name}.log 2>&1

combine_functcov:
	mkdir -p ${SIM}/questa/fcov
	mkdir -p ${SIM}/questa/fcov_logs
	cd ${SIM}/questa/fcov && rm -rf *
	cd ${SIM}/questa/fcov_ucdb && rm -rf *
	wsim rv64gc ${WALLY}/tests/functcov/rv64/I/WALLY-COV-add.elf --fcov > ${SIM}/questa/fcov_logs/add.log 2>&1
	wsim rv64gc ${WALLY}/tests/functcov/rv64/I/WALLY-COV-and.elf --fcov > ${SIM}/questa/fcov_logs/and.log 2>&1

	#run-elf-cov.bash --seed ${SIM}/questa/seed0.txt --verbose --coverdb ${SIM}/questa/fcov/add.ucdb --elf ${WALLY}/tests/functcov/rv64/I/WALLY-COV-add.elf								>> ${SIM}/questa/fcov_logs/add.log 2>&1
	#run-elf-cov.bash --seed ${SIM}/questa/seed0.txt --verbose --coverdb ${SIM}/questa/fcov/and.ucdb --elf ${WALLY}/tests/functcov/rv64/I/WALLY-COV-and.elf								>> ${SIM}/questa/fcov_logs/add.log 2>&1
	#run-elf-cov.bash --seed ${SIM}/questa/seed0.txt --verbose --coverdb ${SIM}/questa/fcov/ori.ucdb --elf ${WALLY}/tests/functcov/rv64/I/WALLY-COV-ori.elf								>> ${SIM}/questa/fcov_logs/add.log 2>&1

	vcover merge ${SIM}/questa/fcov_ucdb/fcov.ucdb ${SIM}/questa/fcov_ucdb/*.ucdb -suppress 6854 -64
	vcover report -details -html ${SIM}/questa/fcov_ucdb/fcov.ucdb
	vcover report ${SIM}/questa/fcov_ucdb/fcov.ucdb -details -cvg > ${SIM}/questa/fcov/fcov.log
	vcover report ${SIM}/questa/fcov_ucdb/fcov.ucdb -testdetails -cvg > ${SIM}/questa/fcov/fcov.testdetails.log
#	vcover report ${SIM}/questa/fcov/fcov.ucdb -details -cvg -below 100 | grep -E "Coverpoint|Covergroup|Cross" | grep -v Metric > ${SIM}/questa/fcov/fcov.ucdb.summary.log
	vcover report ${SIM}/questa/fcov_ucdb/fcov.ucdb -details -cvg | grep -E "Coverpoint|Covergroup|Cross|TYPE"  > ${SIM}/questa/fcov/fcov.summary.log
	grep "Total Coverage By Instance" ${SIM}/questa/fcov/fcov.log

remove_functcov_artifacts:
	rm -rf ${SIM}/questa/riscv.ucdb ${SIM}/questa/fcov.log ${SIM}/questa/covhtmlreport/ ${SIM}/questa/fcov_logs/ ${SIM}/questa/fcov_ucdb/ ${SIM}/questa/fcov/

benchmarks:
	$(MAKE) -C ${WALLY}benchmarks/embench build
	$(MAKE) -C ${WALLY}/benchmarks/embench size
	$(MAKE) -C ${WALLY}/benchmarks/embench modelsim_build_memfile
	$(MAKE) -C ${WALLY}/benchmarks/coremark

clean:
