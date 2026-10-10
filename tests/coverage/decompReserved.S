///////////////////////////////////////////
// decompReserved.S
//
// Written: david_harris@hmc.edu 29 May 2026
//
// Purpose: Coverage for the compressed-instruction decoder (src/ifu/decompress.sv).
//          Closes the uncovered branch at decompress.sv:164 ("All False") and the
//          condition (rds1 != 5'b0)_0 in the c.jr decode:
//              5'b10100: if (instr16[12]==0) if (rs2==0) if (rds1 != 5'b0) ... // c.jr
//          c.jr requires rs1 != 0; the rs1==0 form (instr 0x8002) is a RESERVED
//          encoding that no compiler emits, so the rds1==0 / all-false path was never
//          exercised. Emitting the raw 16-bit reserved instruction drives the decoder
//          down that path (it raises an illegal-instruction trap, which the harness
//          trap handler skips by advancing mepc past the 2-byte instruction).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////


#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// Execute a reserved 16-bit encoding and check that it raised an illegal instruction exception
// (mcause = 2) at its own address.  The trap handler advances mepc past the 2-byte instruction
// and returns, leaving mcause and mepc for the check.
.macro RESERVED16 encoding, index
    csrw mcause, zero
1:
    .2byte \encoding
    csrr t2, mcause
    li t3, 2
    SC_CHECK_EQ t2, t3, \index
    csrr t2, mepc
    la t3, 1b + 2
    SC_CHECK_EQ t2, t3, \index + 1
.endm

main:
    # c.jr x0 : funct3=100, instr16[12]=0, rs1=00000, rs2=00000, op=10  => 0x8002
    # This is the RESERVED c.jr encoding (c.jr is only defined for rs1 != 0).
    # The decompressor evaluates `if (rds1 != 5'b0)` at decompress.sv:164 with rds1==0,
    # taking the previously-uncovered all-false branch / (rds1!=0)_0 condition.
    RESERVED16 0x8002, 1

    # c.ldsp x0 : funct3=011, rd=00000, op=10  => 0x6002
    # c.ldsp is only defined for rd != 0, so this is the RESERVED encoding.  It reaches the
    # `else if (rds1 != 5'b0)` guard on the RV64 arm of case 5'b10011 in decompress.sv with
    # rds1 == 0, which nothing else exercises.  riscv-arch-test does not cover it: its compressed
    # instruction coverpoints ignore the whole c.lwsp/c.ldsp/c.fldsp ranges.
    RESERVED16 0x6002, 3

    SC_PASS
    j done
