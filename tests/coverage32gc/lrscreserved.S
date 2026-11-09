///////////////////////////////////////////
// lrscreserved.S
//
// Written: David_Harris@hmc.edu 7 November 2026
//
// Purpose: lr and sc encodings with byte, halfword, or (on RV32) doubleword widths are reserved: their funct5 matches lr/sc
//          but funct3 is not .w, so the decoder must not take them as lr/sc (controller A3264FunctD_0
//          conditions).  Each is an illegal instruction, which the trap handler skips.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"

main:
    la x10, buf
    .word 0x100502af        # lr.b x5, (x10)
    .word 0x186502af        # sc.b x5, x6, (x10)
    .word 0x100512af        # lr.h x5, (x10)
    .word 0x186512af        # sc.h x5, x6, (x10)
    .word 0x100532af        # lr.d x5, (x10)
    .word 0x186532af        # sc.d x5, x6, (x10)
    j done

.data
.align 4
buf:
    .word 0, 0, 0, 0
