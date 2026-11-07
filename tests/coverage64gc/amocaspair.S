///////////////////////////////////////////
// amocaspair.S
//
// Written: David_Harris@hmc.edu 7 November 2026
//
// Purpose: amocas.q reads rs2+1 of its register pair straight from the register file, so it must wait for an
//          older instruction in Execute or Memory that writes rs2+1 (controller CASMatchE/CASMatchM, the
//          (Rs2D | 1) == RdE/RdM terms), even when that instruction writes neither rd nor rd+1.
//          Passes if it runs to completion (ImperasDV lockstep checks the values).
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
    li x12, 1
    li x14, 0
    li x15, 0
    addi x13, x0, 2         # rs2+1, still in Execute when the amocas.q is in Decode
    .word 0x28c5472f        # amocas.q x14, x12, (x10)
    addi x13, x0, 3         # rs2+1, in Memory when the amocas.q is in Decode
    addi x0, x0, 0
    .word 0x28c5472f        # amocas.q x14, x12, (x10)
    j done

.data
.align 4
buf:
    .dword 0, 0
