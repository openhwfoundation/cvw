# Jordan Carlin, jcarlin@hmc.edu, September 20 2024
# Makefile to generate RISCV floating point testvectors for CORE-V-Wally
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

.DELETE_ON_ERROR:
.ONESHELL:
SHELL := /bin/bash

TESTFLOAT_DIR := ${WALLY}/addins/berkeley-testfloat-3/build/Linux-x86_64-GCC
TESTFLOAT_GEN := ${TESTFLOAT_DIR}/testfloat_gen

# List of testvectors to generate. Each rounding mode will be generated for each test.
cvtint := ui32_to_f16 ui32_to_f32 ui32_to_f64 ui32_to_f128 \
          ui64_to_f16 ui64_to_f32 ui64_to_f64 ui64_to_f128 \
          i32_to_f16 i32_to_f32 i32_to_f64 i32_to_f128 \
          i64_to_f16 i64_to_f32 i64_to_f64 i64_to_f128 \
          f16_to_ui32 f32_to_ui32 f64_to_ui32 f128_to_ui32 \
          f16_to_ui64 f32_to_ui64 f64_to_ui64 f128_to_ui64
cvtfp := f16_to_i32 f32_to_i32 f64_to_i32 f128_to_i32 \
         f16_to_i64 f32_to_i64 f64_to_i64 f128_to_i64 \
         f16_to_f32 f16_to_f64 f16_to_f128 \
         f32_to_f16 f32_to_f64 f32_to_f128 \
         f64_to_f16 f64_to_f32 f64_to_f128 \
         f128_to_f16 f128_to_f32 f128_to_f64
add := f16_add f32_add f64_add f128_add
sub := f16_sub f32_sub f64_sub f128_sub
mul := f16_mul f32_mul f64_mul f128_mul
div := f16_div f32_div f64_div f128_div
sqrt := f16_sqrt f32_sqrt f64_sqrt f128_sqrt
eq := f16_eq f32_eq f64_eq f128_eq
le := f16_le f32_le f64_le f128_le
lt := f16_lt f32_lt f64_lt f128_lt
mulAdd := f16_mulAdd f32_mulAdd f64_mulAdd f128_mulAdd
# Zfa: fleq/fltq are quiet comparisons; fround/froundnx round to an integer without/with the inexact flag
le_quiet := f16_le_quiet f32_le_quiet f64_le_quiet f128_le_quiet
lt_quiet := f16_lt_quiet f32_lt_quiet f64_lt_quiet f128_lt_quiet
roundToInt := f16_roundToInt f32_roundToInt f64_roundToInt f128_roundToInt
roundToIntExact := f16_roundToIntExact f32_roundToIntExact f64_roundToIntExact f128_roundToIntExact

tests := $(cvtfp) $(cvtint) $(add) $(sub) $(mul) $(div) $(sqrt) $(eq) $(le) $(lt) $(mulAdd) \
         $(le_quiet) $(lt_quiet) $(roundToInt) $(roundToIntExact)

# Set rounding modes and extensions
rne: ROUND_MODE := rnear_even
rne: ROUND_EXT  := rne
rz: ROUND_MODE  := rminMag
rz: ROUND_EXT   := rz
ru: ROUND_MODE  := rmax
ru: ROUND_EXT   := ru
rd: ROUND_MODE  := rmin
rd: ROUND_EXT   := rd
rnm: ROUND_MODE := rnear_maxMag
rnm: ROUND_EXT  := rnm

.PHONY: all rne rz ru rd rnm clean

# Generate all test vectors
all: rne rz ru rd rnm

# Generate test vectors for each rounding mode
rne: $(addsuffix _rne.tv, $(tests))
rz: $(addsuffix _rz.tv, $(tests))
ru: $(addsuffix _ru.tv, $(tests))
rd: $(addsuffix _rd.tv, $(tests))
rnm: $(addsuffix _rnm.tv, $(tests))

# Rule to generate individual test vectors
%.tv: ${TESTFLOAT_GEN}
	@echo Creating $@ vectors
	@if [[ "$*" =~ "to" ]] || [[ "$*" =~ "sqrt" ]] || [[ "$*" =~ "roundToInt" ]] ; then level=2 ; else level=1 ; fi
	@if [[ "$*" =~ "to_i" ]] || [[ "$*" =~ "to_u" ]] || [[ "$*" =~ "roundToIntExact" ]] ; then exact="-exact" ; else exact="" ; fi
	${TESTFLOAT_GEN}  -tininessafter -level $$level $$exact -$(ROUND_MODE) $(subst roundToIntExact,roundToInt,$(patsubst %_$(ROUND_EXT).tv, %, $@)) > $@
	@sed -i 's/ /_/g' $@

# Generate TestFloat first if necessary
${TESTFLOAT_GEN}:
	$(MAKE) -C ${WALLY}/tests/fp testfloat

clean:
	rm -f *.tv
	rm -f sed*
