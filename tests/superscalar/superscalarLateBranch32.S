///////////////////////////////////////////
// superscalarLateBranch32.S
//
// Written: jgong@g.hmc.edu 26 October 2026
//
// Purpose: Self-checking RV32 test for late branches.  A slot 0 conditional branch whose operand the
//          bundle just ahead produces too late to compare in Execute (a load, a multiply, a CSR read,
//          a late slot 1) is not stalled: it goes the way fetch went, and the late ALU checks its
//          direction in Memory (ieu.sv).  If fetch was wrong, the Memory stage redirects.  Checks:
//            - all six branch conditions, signed and unsigned, at the sign-boundary values, both ways
//            - the late operand as rs1, as rs2, and as both
//            - the producer in slot 0 and in slot 1 of the bundle ahead
//            - load, multiply, CSR read and late-ALU producers
//            - a slot 1 beside a late branch that turns out taken, which must not commit
//            - a wrong-path divide and a wrong-path store behind a late branch, which must not act
//            - a compressed branch on a compressed load
//            - a loop whose exit test is a late branch
//          Every case runs four times in a loop, so the predictor gets it wrong first and right
//          after, and the whole set is run twice, the second time shifted by 4 bytes.  The
//          testbench's "late branch" line counts how many resolved in Memory and how many redirected.
//          A failing check stores (index << 1) | 1 to tohost.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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

// s6 points at the data table.  t0, t1 and t2 are reserved for CHECK and the trap handler.
// s11 counts loop iterations; s10 counts how often the taken path was reached.

.section .text.init
.global rvtest_entry_point
rvtest_entry_point:
    la t0, trap_handler
    csrw mtvec, t0
    j main

// No trap is expected
.align 2
trap_handler:
    li t1, 0xFFFF
    j fail

pass:
    la t0, tohost
    li t1, 1
    sw t1, 0(t0)
1:  j 1b

// t1 holds (index << 1) | 1
fail:
    la t0, tohost
    sw t1, 0(t0)
1:  j 1b

.macro CHECK reg, value, index
    li t2, \value
    beq \reg, t2, 1f
    li t1, ((\index) << 1) | 1
    j fail
1:
.endm

// Run a branch on a freshly loaded value four times.  The load reads word \off of the table into s2;
// \br compares it with s3 (= \other) in the order given by \a, \b.  \taken says which way it must go.
// The instruction after the branch sits in slot 1 beside it and must commit only if not taken.
.macro LDBR br, a, b, off, other, taken, index
    li   s11, 4
    li   s10, 0
    li   s4, 0
    li   s3, \other
2:  lw   s2, \off(s6)
    \br  \a, \b, 3f
    addi s4, s4, 1          // fall-through, beside the branch in slot 1
    j    4f
3:  addi s10, s10, 1        // taken path
4:  addi s11, s11, -1
    bnez s11, 2b
    .if \taken
    CHECK s10, 4, \index
    CHECK s4, 0, \index
    .else
    CHECK s10, 0, \index
    CHECK s4, 4, \index
    .endif
.endm

.macro BRCASES base
    .option push
    .option norvc

    // table: 0: 5   4: 0xFFFFFFFD (-3)   8: 0x80000000   12: 0x7FFFFFFF   16: 0
    LDBR beq,  s2, s3, 0,  5,          1, \base+1
    LDBR beq,  s2, s3, 0,  6,          0, \base+2
    LDBR bne,  s2, s3, 0,  6,          1, \base+3
    LDBR bne,  s2, s3, 0,  5,          0, \base+4
    LDBR blt,  s2, s3, 4,  5,          1, \base+5     // -3 < 5
    LDBR blt,  s3, s2, 4,  5,          0, \base+6     // 5 < -3 is false; load is rs2
    LDBR bge,  s2, s3, 4,  5,          0, \base+7
    LDBR bge,  s3, s2, 4,  5,          1, \base+8
    LDBR bltu, s2, s3, 4,  5,          0, \base+9     // 0xFFFFFFFD <u 5 is false
    LDBR bltu, s3, s2, 4,  5,          1, \base+10
    LDBR bgeu, s2, s3, 4,  5,          1, \base+11
    LDBR bgeu, s3, s2, 4,  5,          0, \base+12
    LDBR blt,  s2, s3, 8,  0x7FFFFFFF, 1, \base+13    // INT_MIN < INT_MAX
    LDBR bltu, s2, s3, 8,  0x7FFFFFFF, 0, \base+14    // 0x80000000 <u 0x7FFFFFFF is false
    LDBR bge,  s2, s3, 12, 0x80000000, 1, \base+15
    LDBR bgeu, s2, s3, 12, 0x80000000, 0, \base+16
    LDBR blt,  s2, s3, 0,  5,          0, \base+17    // equal values
    LDBR bge,  s2, s3, 0,  5,          1, \base+18
    LDBR bltu, s2, s3, 0,  5,          0, \base+19
    LDBR bgeu, s2, s3, 0,  5,          1, \base+20
    LDBR beq,  s2, s2, 0,  0,          1, \base+21    // both operands are the load
    LDBR bne,  s2, zero, 16, 0,        0, \base+22    // against x0

    // The load in slot 1 of the bundle ahead, then in slot 0, depending on alignment: a filler ALU
    // operation ahead of it puts it in the other slot from the cases above.
    li   s11, 4
    li   s10, 0
    li   s3, 5
1:  addi s5, zero, 0
    lw   s2, 0(s6)
    beq  s2, s3, 2f
    j    3f
2:  addi s10, s10, 1
3:  addi s11, s11, -1
    bnez s11, 1b
    CHECK s10, 4, \base+23

    // A multiply result
    li   s11, 4
    li   s10, 0
    li   s3, 49
1:  li   s4, -7
    mul  s2, s4, s4
    beq  s2, s3, 2f
    j    3f
2:  addi s10, s10, 1
3:  addi s11, s11, -1
    bnez s11, 1b
    CHECK s10, 4, \base+24

    // A late slot 1 result: s2 = s5 + 1 is computed by the late ALU, then compared by it again
    li   s11, 4
    li   s10, 0
    li   s3, 6
1:  addi s5, zero, 5
    addi s2, s5, 1
    bne  s2, s3, 2f         // never taken
    addi s10, s10, 1
2:  addi s11, s11, -1
    bnez s11, 1b
    CHECK s10, 4, \base+25

    // A CSR read
    li   s11, 4
    li   s10, 0
    li   s3, 0x1234
    csrw mscratch, s3
1:  csrr s2, mscratch
    beq  s2, s3, 2f
    j    3f
2:  addi s10, s10, 1
3:  addi s11, s11, -1
    bnez s11, 1b
    CHECK s10, 4, \base+26

    // The direction alternates every iteration, so the predictor keeps getting it wrong both ways:
    // predicted taken but falling through, and predicted not taken but taken.  The path counts show
    // that each wrong-path instruction was squashed, including the slot 1 beside the branch.
    li   s11, 8
    li   s10, 0
    li   s4, 0
    li   s9, 0
1:  sw   s9, 24(s6)         // alternate 0 / 1 in word 24
    lw   s2, 24(s6)
    bnez s2, 2f             // taken on odd iterations
    addi s4, s4, 1          // fall-through, beside the branch
    j    3f
2:  addi s10, s10, 1        // taken path
3:  xori s9, s9, 1
    addi s11, s11, -1
    bnez s11, 1b
    CHECK s4, 4, \base+27
    CHECK s10, 4, \base+28
    lw   s2, 20(s6)
    CHECK s2, 0, \base+29

    // Taken late branch whose fall-through is a divide and a store: on the first iteration nothing is
    // in the BTB, so fetch falls through, both are fetched behind the branch and must be squashed --
    // the divide while already busy in Execute.
    li   a0, 1000
    li   a2, 7
    li   s11, 4
    li   s8, 0x66
    li   s3, 5
1:  lw   s2, 0(s6)
    beq  s2, s3, 2f
    div  s8, a0, a2
    sw   a0, 20(s6)
2:  addi s11, s11, -1
    bnez s11, 1b
    CHECK s8, 0x66, \base+30
    lw   s2, 20(s6)
    CHECK s2, 0, \base+31

    // A loop whose exit test is a late branch: sum the table's zero-terminated list at 28
    li   s10, 0
    addi s9, s6, 28
1:  lw   s2, 0(s9)
    beqz s2, 2f
    add  s10, s10, s2
    addi s9, s9, 4
    j    1b
2:  CHECK s10, 15, \base+32
    .option pop

    // Compressed branch on a compressed load (x8-x15 only)
    .option push
    .option rvc
    li   s11, 4
    li   s10, 0
    mv   a5, s6
1:  c.lw a4, 16(a5)         // 0
    c.beqz a4, 2f
    j    3f
2:  addi s10, s10, 1
3:  addi s11, s11, -1
    bnez s11, 1b
    CHECK s10, 4, \base+33
    .option pop
.endm

main:
    la s6, tdata

    .align 3
    BRCASES 0x100

    .align 3
    .option push
    .option norvc
    nop                     // 4 bytes, so every pair of the second pass falls differently in the window
    .option pop
    BRCASES 0x200

    j pass

.section .tohost
.align 3
tohost:
    .dword 0
fromhost:
    .dword 0

.data
.align 3
tdata:
    .word 5             // 0
    .word 0xFFFFFFFD    // 4
    .word 0x80000000    // 8
    .word 0x7FFFFFFF    // 12
    .word 0             // 16
    .word 0             // 20: must never be written
    .word 0             // 24: scratch
    .word 1, 2, 3, 4, 5, 0   // 28: list summing to 15
