///////////////////////////////////////////
// superscalarMul.S
//
// Written: jgong@g.hmc.edu 13 October 2026
//
// Purpose: Self-checking test for multiplies in superscalar slot 1.  The core has one multiplier;
//          ieu.sv steers its operands, funct3 and W64 to whichever slot holds the bundle's multiply,
//          and slot 1's writeback takes the product.  Each case places a multiply as the second
//          instruction of a likely pair and checks:
//            - every multiply variant (mul, mulh, mulhsu, mulhu, mulw) next to a slot 0 ALU op
//            - a product used by the very next pair, from slot 0 and from slot 1 (MDUStall1D)
//            - two multiplies in one fetch window, which must not pair (OneMduOpF)
//            - a load in slot 0 beside a slot 1 multiply
//            - a taken branch in slot 0, which must keep the slot 1 multiply from writing
//            - a not-taken branch in slot 0, whose slot 1 multiply must write
//            - a load access fault in slot 0, after which the multiply must run exactly once
//            - a compressed slot 0 beside a slot 1 multiply
//          Pairing depends on where the two instructions fall in the fetch window, so every case is
//          run twice, the second time shifted by 4 bytes.  The testbench's "slot1 mul" count shows
//          how many multiplies actually issued from slot 1.
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

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// Operands: a0 = A, a1 = B, a2 = C, a3 = D.  The SC_* macros clobber t0 and t1.
#define A 0xFEDCBA9876543210
#define B 0x0123456789ABCDEF
#define C 0xFFFFFFFFFFFFFFF9
#define D 0x7FFFFFFFFFFFFFFF

.macro CHECK reg, value, index
    li t2, \value
    SC_CHECK_EQ \reg, t2, \index
.endm

// One pass over every case.  Indices start at \base so a failure says which pass it came from.
.macro MULCASES base
    .option push
    .option norvc

    // Every variant, each beside an independent ALU op in slot 0
    addi s2, zero, 5
    mul s3, a0, a1
    addi s4, zero, 6
    mulh s5, a0, a2
    addi s6, zero, 7
    mulhsu s7, a0, a2
    addi s8, zero, 8
    mulhu s9, a0, a2
    addi s10, zero, 9
    mulw s11, a0, a1
    CHECK s3, 0x2236D88FE5618CF0, \base+1
    CHECK s5, 0x0, \base+2
    CHECK s7, 0xFEDCBA9876543210, \base+3
    CHECK s9, 0xFEDCBA9876543209, \base+4
    CHECK s11, 0xFFFFFFFFE5618CF0, \base+5
    CHECK s2, 5, \base+6
    CHECK s10, 9, \base+7

    // The product is used by the very next pair, from both slots.  Forwarding it from slot 1's
    // Memory stage would supply the ALU output instead, so MDUStall1D must hold the pair a cycle.
    addi t3, zero, 1
    mul t4, a2, a3
    add t5, t4, t3
    add t6, t4, a2
    CHECK t4, 0x8000000000000007, \base+8
    CHECK t5, 0x8000000000000008, \base+9
    CHECK t6, 0x8000000000000000, \base+10

    // Two multiplies side by side: one multiplier, so they must issue one at a time
    mul a4, a0, a1
    mul a5, a1, a3
    CHECK a4, 0x2236D88FE5618CF0, \base+11
    CHECK a5, 0x7EDCBA9876543211, \base+12

    // A load in slot 0 beside a slot 1 multiply: the two units are steered independently
    la t2, mdata
    ld a6, 0(t2)
    mul a7, a1, a3
    CHECK a6, 0x1122334455667788, \base+13
    CHECK a7, 0x7EDCBA9876543211, \base+14

    // A branch in slot 0 that is taken: the slot 1 multiply is the fall-through and must not write.
    // rd = rs1, so a multiply that wrongly committed would leave 11 * B behind.
    li s2, 11
    beq zero, zero, 1f
    mul s2, s2, a1
1:
    CHECK s2, 11, \base+15

    // A branch in slot 0 that is not taken: the slot 1 multiply must write
    li s4, 13
    bne zero, zero, 2f
    mul s4, s4, a1
2:
    CHECK s4, 0x0ECA8641FDB97523, \base+16

    // A load access fault in slot 0.  The trap flushes the slot 1 multiply, the handler skips the
    // load, and the multiply then runs on its own.  rd = rs1, so if the flushed copy had also
    // written, the result would be 11 * B * B rather than 11 * B.
    li s6, 11
    li a6, 0x90000000
    ld a6, 0(a6)
    mul s6, s6, a1
    CHECK s6, 0x0C83FB72EA61D945, \base+17

    // A compressed slot 0 beside a slot 1 multiply
    .option push
    .option rvc
    c.li s8, 3
    .option pop
    mul s9, a1, a3
    CHECK s8, 3, \base+18
    CHECK s9, 0x7EDCBA9876543211, \base+19

    .option pop
.endm

main:
    li a0, A
    li a1, B
    li a2, C
    li a3, D

    .align 3
    MULCASES 0x100

    .align 3
    .option push
    .option norvc
    nop                     // 4 bytes, so every pair of the second pass straddles a different boundary
    .option pop
    MULCASES 0x200

    SC_PASS
    j done

.data
.align 3
mdata:
    .8byte 0x1122334455667788
