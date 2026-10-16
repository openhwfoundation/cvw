///////////////////////////////////////////
// lsu.S
//
// Written: Kevin Box and Miles Cook kbox@hmc.edu mdcook@hmc.edu 26 March 2023
//
// Purpose: Test coverage for lsu
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"

main:

    sfence.vma x0, x0 // sfence.vma to assert TLBFlush

    li a0, 0x80000001   # misaligned address
    amoadd.w t0, a0, (a0) # amo access to misaligned address

    j done
