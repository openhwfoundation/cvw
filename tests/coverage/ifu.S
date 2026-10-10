///////////////////////////////////////////
// ifu.S
//
// Written: sriley@g.hmc.edu 28 March 2023
//
// Purpose: Test coverage for IFU
//          Checks the values loaded and stored by the compressed FP and Zcb loads and stores
//          and computed by c.mul and the Zcb extend/not instructions, that each reserved
//          compressed encoding raises an illegal instruction exception at its own address,
//          and that the c.slli HINT does not trap.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// CHECKX reg, val, index: check an integer register
.macro CHECKX reg, val, index
    li t2, \val
    SC_CHECK_EQ \reg, t2, \index
.endm

// CHECKF freg, val, index: check all 64 bits of an FP register
.macro CHECKF freg, val, index
    fmv.x.d t3, \freg
    li t2, \val
    SC_CHECK_EQ t3, t2, \index
.endm

// RES16 encoding, index: execute a reserved 16-bit encoding and check that it raised an illegal
// instruction exception (mcause = 2) at its own address.  The library trap handler advances mepc past
// the 2-byte instruction and returns, leaving mcause and mepc for the check.
.macro RES16 encoding, index
    csrw mcause, zero
1:
    .2byte \encoding
    csrr t3, mcause
    CHECKX t3, 2, \index
    csrr t3, mepc
    la t2, 1b + 2
    SC_CHECK_EQ t3, t2, \index + 1
.endm

main:
    # turn floating point on
    li t0, 0x2000
    csrs mstatus, t0

    # Data for the loads and stores below.  Memory at sp starts as 0x0123456789ABCDEF; c.fsd stores fs1
    # and c.fsdsp stores f1, so every load and store leaves a different value.
    li t2, 0x0123456789ABCDEF
    sd t2, 0(sp)
    li t2, 0xFEDCBA9876543210
    fmv.d.x fs1, t2
    li t2, 0x1122334455669988
    fmv.d.x f1, t2
    li a3, 0x5A             // stored by c.sb
    li a4, 0x3CC3           // stored by c.sh

    # calling compressed floating point load double instruction
    //.hword 0x2000 // CL type compressed floating-point ld-->funct3,imm,rs1',imm,rd',op
                        // binary version 0000 0000 0000 0000 0010 0000 0000 0000
    mv s0, sp
    c.fld fs0, 0(s0)    // Previously uncovered instructions
    c.fsd fs1, 0(s0)
    .hword 0x2002      // c.fldsp f0, 0
    .hword 0xA006      // c.fsdsp f1, 0
    .hword 0x9C41      // c.mul s0, s0 (Zcb): s0 = sp * sp
    mul t2, sp, sp
    SC_CHECK_EQ s0, t2, 1
    CHECKF fs0, 0x0123456789ABCDEF, 2   // c.fld read the initial value
    CHECKF f0, 0xFEDCBA9876543210, 3    // c.fldsp read what c.fsd stored
    ld t3, 0(sp)
    CHECKX t3, 0x1122334455669988, 4    // c.fsdsp stored f1

    # Zcb coverage tests
    mv s0, sp
    c.lbu a1, 0(s0)   // exercise c.lbu
    c.lh a2, 0(s0)    // exercise c.lh
    c.lhu s1, 0(s0)   // exercise c.lhu
    c.sb a3, 0(s0)    // exercise c.sb
    lbu t3, 0(s0)
    CHECKX t3, 0x5A, 5
    c.sh a4, 0(s0)    // exercise c.sh
    CHECKX a1, 0x88, 6
    CHECKX a2, 0xFFFFFFFFFFFF9988, 7    // sign-extended
    CHECKX s1, 0x9988, 8
    ld t3, 0(s0)
    CHECKX t3, 0x1122334455663CC3, 9    // c.sh replaced the c.sb byte and the next one

    RES16 0x2005, 10   // line 110: c.addiw with rd = 0 is reserved
    RES16 0x6101, 12   // line 114: c.addi16sp with imm = 0 is reserved
    RES16 0x6201, 14   // line 115: c.lui with imm = 0 is reserved
    csrw mcause, zero
    .hword 0x0202      // c.slli x4, 0 is a HINT, so it must not trap (op = 10, Instr[15:13] = 000)
    csrr t3, mcause
    SC_CHECK_EQ t3, zero, 16
    RES16 0x4002, 17   // Illegal compressed instruction with op = 10, Instr[15:13] = 010, c.lwsp zero, 0. Line 158 illegal instruction
    RES16 0x8C44, 19   // Illegal compressed instruction with op = 00, Instr[15:10] = 100011, Instr[6] = 1 and 0's everywhere else. Line 119 illegal instruction
    RES16 0x9C00, 21   // Illegal compressed instruction with op = 00, Instr[15:10] = 100111, and 0's everywhere else. Line 119 illegal instruction

    li s0, 0xA5A5A5A5A5A5A5FF   // upper bits set so c.zext.b changes the value
    c.zext.b s0      // exercise c.zext.b
    CHECKX s0, 0xFF, 23
    c.sext.b s0      // exercise c.sext.b
    CHECKX s0, 0xFFFFFFFFFFFFFFFF, 24
    c.zext.h s0      // exercise c.zext.h
    CHECKX s0, 0xFFFF, 25
    c.sext.h s0      // exercise c.sext.h
    CHECKX s0, 0xFFFFFFFFFFFFFFFF, 26
    c.zext.w s0      // exercise c.zext.w
    CHECKX s0, 0xFFFFFFFF, 27
    c.not s0         // exercise c.not
    CHECKX s0, 0xFFFFFFFF00000000, 28

    RES16 0x9C7D, 29   // Reserved instruction from line 187 with op = 01, Instr[15:10] = 100111, Instr[6:5] = 11, and 0's everywhere else

    # exercise all the cache ways
    j way0code

# stress test cache ways by loading stuff from each one and then doing fence.i to invalidate
.align 12
way0code:
    jal way1code
1:  fence.i
    la t2, 1b
    SC_CHECK_EQ ra, t2, 31  // the chain of jumps through the other ways returned here
    SC_PASS
    j done

.align 12
way1code:
    j way2code

.align 12
way2code:
    j way3code

.align 12
way3code:
    j way00code

.align 12
way00code:
    ret


    j done
