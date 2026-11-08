///////////////////////////////////////////
// superscalarBranchKill32.S
//
// Purpose: Self-checking RV32 test for a slot 1 killed by a taken branch in slot 0.  The killed
//          fall-through still reaches Memory with its result computed, so nothing may forward it.
//          The case that exposes this is the compiler's skip-one idiom, `bxx +8` with the skipped
//          instruction in slot 1: the taken target is the next sequential bundle, so there is no
//          misprediction and no flush, and the target enters Execute while the dead instruction is
//          in Memory, then the bundle after it while the dead instruction is in Writeback.  Each case
//          reads the poisoned register from slot 1 (c1's own forwarding) and from slot 0 (slot 0
//          forwarding from slot 1) at both distances.  Every case is run twice, the second time
//          shifted by 4 bytes, and the testbench's "slot1 kills" count shows how many were killed.
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

// s3 holds 1 throughout; the skipped addi would make it 0x101.  s6 = 1 makes every bnez taken.
.macro KILLCASES base
    li s3, 1
    li s6, 1
    .align 3
    bnez s6, 1f                 // slot 0: taken, target = the next bundle
    addi s3, s3, 0x100          // slot 1: skipped, killed in Execute
1:  addi s4, zero, 0            // slot 0                   dead addi in Memory
    add  s5, zero, s3           // slot 1 reads s3
    addi s4, zero, 0            // slot 0                   dead addi in Writeback
    add  s7, zero, s3           // slot 1 reads s3
    CHECK s5, 1, \base+1
    CHECK s7, 1, \base+2
    CHECK s3, 1, \base+3

    .align 3
    bnez s6, 1f
    addi s3, s3, 0x100
1:  add  s5, zero, s3           // slot 0 reads s3            dead addi in Memory
    addi s4, zero, 0
    add  s7, zero, s3           // slot 0 reads s3            dead addi in Writeback
    addi s4, zero, 0
    CHECK s5, 1, \base+4
    CHECK s7, 1, \base+5
    CHECK s3, 1, \base+6

    // Not taken: the addi is live and its result must be forwarded
    li s6, 0
    .align 3
    bnez s6, 1f
    addi s3, s3, 0x100
1:  addi s4, zero, 0
    add  s5, zero, s3
    CHECK s5, 0x101, \base+7
.endm

main:
    .option push
    .option norvc
    KILLCASES 0x100
    .align 3
    nop                         // 4 bytes, so every pair of the second pass falls differently in the window
    KILLCASES 0x200
    .option pop
    j pass

.section .tohost
.align 3
tohost:
    .dword 0
fromhost:
    .dword 0
