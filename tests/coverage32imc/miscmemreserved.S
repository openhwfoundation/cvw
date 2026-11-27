///////////////////////////////////////////
// miscmemreserved.S
//
// Written: david_harris@hmc.edu 27 November 2026
//
// Purpose: rv32imc decoder coverage.  The MISC-MEM opcode (0001111) is only legal as fence (funct3 000)
//          on rv32imc, which has no Zifencei and no cache management extensions.  Executes the opcode
//          with funct3 001 (fence.i), 010 (cbo.inval) and 100 (reserved in every configuration); each
//          must raise an illegal instruction exception.  This is the path of the controller's MISC-MEM
//          decode that is neither a fence nor a cache management operation.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// RESERVED32 encoding, index: the 32-bit encoding must trap as an illegal instruction (mcause 2) with
// mepc at the encoding and mtval holding it.  The library handler returns past it (mepc + 4).
.macro RESERVED32 encoding, index
    csrw mcause, zero
1:
    .4byte \encoding
    csrr t2, mcause
    li t3, 2
    SC_CHECK_EQ t2, t3, \index
    csrr t2, mepc
    la t3, 1b + 4
    SC_CHECK_EQ t2, t3, \index + 1
    csrr t2, mtval
    li t3, \encoding
    SC_CHECK_EQ t2, t3, \index + 2
.endm

main:
    RESERVED32 0x0000100F, 1    // fence.i: no Zifencei
    RESERVED32 0x0000200F, 4    // cbo.inval (x0): no Zicbom
    RESERVED32 0x0000400F, 7    // MISC-MEM funct3 100: reserved

    // an ordinary fence is still legal and executes as a nop
    csrw mcause, zero
    fence
    csrr t2, mcause
    SC_CHECK_EQ t2, zero, 10

    SC_PASS
    j done
