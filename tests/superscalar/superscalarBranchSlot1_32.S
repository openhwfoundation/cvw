///////////////////////////////////////////
// superscalarBranchSlot1_32.S
//
// Purpose: Self-checking RV32 test for a conditional branch in slot 1.  Slot 1 resolves the branch
//          with its own comparator, and the predictor learns it at the bundle's address, so a loop
//          whose back-edge sits in slot 1 runs first mispredicted and then predicted taken.  Each
//          case checks that slot 0 of the branch's bundle commits, that the instruction after a
//          taken slot 1 branch does not, that a not-taken one falls through after the bundle, and
//          that slot 1's operands are forwarded from the bundle ahead.  The signed and unsigned
//          compares and c.bnez in slot 1 are covered too.
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

.section .text.init
.global rvtest_entry_point
rvtest_entry_point:
    j main

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

main:
    .option push
    .option norvc

    // Loop with its back-edge in slot 1, reading a counter written by the bundle ahead of it.
    // s3 counts slot 0 of the branch bundle; s4 counts the instruction after the branch, which runs
    // only once, when the loop exits.
    li s1, 20
    li s2, 0
    li s3, 0
    li s4, 0
    .align 3
1:  addi s1, s1, -1             // slot 0
    addi s2, s2, 1              // slot 1
    addi s3, s3, 2              // slot 0
    bnez s1, 1b                 // slot 1: taken 19 times
    addi s4, s4, 1              // after the bundle
    CHECK s1, 0,  1
    CHECK s2, 20, 2
    CHECK s3, 40, 3
    CHECK s4, 1,  4

    // Taken forward: the skipped instruction must not execute, slot 0 must
    li s5, 0
    li s6, 0
    .align 3
    addi s5, s5, 7              // slot 0
    beq  zero, zero, 2f         // slot 1: taken
    addi s6, s6, 1              // skipped
    addi s6, s6, 2              // skipped
2:  CHECK s5, 7, 5
    CHECK s6, 0, 6

    // Not taken: execution continues after the bundle
    li s5, 0
    .align 3
    addi s5, s5, 1              // slot 0
    bne  zero, zero, 3f         // slot 1: not taken
    addi s5, s5, 2              // next bundle
3:  CHECK s5, 3, 7

    // Signed and unsigned compares in slot 1: -1 < 1 signed, but not unsigned
    li a0, -1
    li a1, 1
    li s5, 0
    .align 3
    addi s7, zero, 0            // slot 0
    blt  a0, a1, 4f             // slot 1: taken
    addi s5, s5, 1
    .align 3
4:
    addi s7, zero, 0            // slot 0
    bltu a0, a1, 5f             // slot 1: not taken
    addi s5, s5, 2
    .align 3
5:
    addi s7, zero, 0            // slot 0
    bgeu a0, a1, 6f             // slot 1: taken
    addi s5, s5, 4
6:  CHECK s5, 2, 8
    .option pop

    // c.bnez in slot 1, as a loop back-edge
    li s1, 10
    li s2, 0
    .align 3
7:  c.addi s1, -1               // slot 0
    c.addi s2, 1                // slot 1
    c.addi s0, 1                // slot 0 (a zero immediate would be a HINT, which does not pair)
    c.bnez s1, 7b               // slot 1
    CHECK s1, 0,  9
    CHECK s2, 10, 10

    j pass

.section .tohost
.align 3
tohost:
    .dword 0
fromhost:
    .dword 0
