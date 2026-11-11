///////////////////////////////////////////
// dummy-libgcc64.c
//
// Written:  David Harris David_Harris@hmc.edu 1 November 2026
// Modified:
//
// Purpose: Dummy versions of the RV64 soft-float helpers missing from embench-iot's support/dummy-libgcc.c,
//          which covers only the 32-bit integer conversions that RV32 needs.  On RV64, long is 64 bits, so
//          statemate, ud, and wikisort call the 64-bit integer/double conversions.  Like the other dummy
//          libraries, these stubs stand in for library code so that the size build measures only
//          benchmark code; they are never run.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

long long __fixdfdi(double a __attribute__((unused))) {
  return 0;
}

double __floatdidf(long long i __attribute__((unused))) {
  return 0.0;
}

double __floatundidf(unsigned long long i __attribute__((unused))) {
  return 0.0;
}
