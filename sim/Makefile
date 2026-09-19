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



.PHONY: QuestaFunctCoverage QuestaCodeCoverage collect_functcov combine_functcov remove_functcov_artifacts riscvdv riscvdv_functcov

# Merge the per-test functional coverage databases written by wsim --fcov and report the total.
QuestaFunctCoverage:
	mkdir -p questa/fcov
	vcover merge -out questa/fcov_ucdb/fcov.ucdb questa/fcov_ucdb/rv64gc*.ucdb -suppress 6854 -64
	vcover report questa/fcov_ucdb/fcov.ucdb -details -cvg > questa/fcov/fcov.log
	vcover report questa/fcov_ucdb/fcov.ucdb -cvg > questa/fcov/fcov.summary.log
	vcover report questa/fcov_ucdb/fcov.ucdb -details -cvg -below 100 > questa/fcov/fcov.uncovered.log
	grep -E "TOTAL COVERGROUP COVERAGE" questa/fcov/fcov.summary.log

QuestaCodeCoverage:
	vcover merge -out questa/ucdb/cov.ucdb questa/ucdb/rv64gc*.ucdb -logfile questa/cov/log
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
