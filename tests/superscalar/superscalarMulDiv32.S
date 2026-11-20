///////////////////////////////////////////
// superscalarMulDiv32.S
//
// Written: jgong@g.hmc.edu 13 October 2026
//
// Purpose: Self-checking RV32 test for multiplies and divides in superscalar slot 1.  The core has
//          one multiply/divide unit; ieu.sv steers its operands, funct3, W64 and divide start to
//          whichever slot holds the bundle's MDU operation, and slot 1's writeback takes the result.
//          Each case places the MDU operation as the second instruction of a likely pair and checks:
//            - every divide and multiply variant beside a slot 0 ALU op
//            - divide by zero and signed overflow (INT_MIN / -1)
//            - a result used by the very next pair, from slot 0 and from slot 1 (MDUStall1D)
//            - two MDU operations in one fetch window, which must not pair (OneMduOpF)
//            - a load in slot 0 beside a slot 1 divide
//            - a branch in slot 0, taken and not taken, beside a divide: never paired, and the taken
//              case must not let the divide write
//            - a load access fault in slot 0, after which the divide must run exactly once
//            - a compressed slot 0 beside a slot 1 divide
//            - the other instruction of a divide's bundle reading a value forwarded from the pair
//              just ahead, which must survive the divide's stall (datapath.sv operand capture)
//          Pairing depends on where the two instructions fall in the fetch window, so every case is
//          run twice, the second time shifted by 4 bytes.  The testbench's "slot1 mul/div" counts show
//          how many actually issued from slot 1.  A failing check stores (index << 1) | 1 to tohost.
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

// Operands: a0 = A, a1 = B, a2 = C, s11 = 7.  t0 and t1 are reserved for CHECK and the trap handler.
#define A 0xFEDCBA98
#define B 0x01234567
#define C 0xFFFFFFF9

.section .text.init
.global rvtest_entry_point
rvtest_entry_point:
    la t0, trap_handler
    csrw mtvec, t0
    j main

// Every trap is expected (the load access fault below); skip the trapping instruction and return.
.align 2
trap_handler:
    csrr t0, mepc
    lhu t1, 0(t0)
    andi t1, t1, 3
    addi t0, t0, 2
    li t2, 3
    bne t1, t2, 1f
    addi t0, t0, 2
1:  csrw mepc, t0
    mret

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

.macro MDUCASES base
    .option push
    .option norvc

    // Every divide variant, each beside an independent ALU op in slot 0
    addi s2, zero, 5
    div s3, a0, a2
    addi s4, zero, 6
    divu s5, a0, a2
    addi s6, zero, 7
    rem s7, a0, a2
    addi s8, zero, 8
    remu s9, a0, a2
    CHECK s3, 0x00299C33, \base+1
    CHECK s5, 0x00000000, \base+2
    CHECK s7, 0xFFFFFFFD, \base+3
    CHECK s9, 0xFEDCBA98, \base+4
    CHECK s2, 5, \base+5
    CHECK s8, 8, \base+6

    // Every multiply variant, likewise
    addi s2, zero, 9
    mul s3, a0, a1
    addi s4, zero, 10
    mulh s5, a0, a2
    addi s6, zero, 11
    mulhsu s7, a0, a2
    addi s8, zero, 12
    mulhu s9, a0, a2
    CHECK s3, 0x23E20B28, \base+7
    CHECK s5, 0x00000000, \base+8
    CHECK s7, 0xFEDCBA98, \base+9
    CHECK s9, 0xFEDCBA91, \base+10
    CHECK s2, 9, \base+11

    // Divide by zero, and the one signed overflow
    li a4, 0x80000000
    li a5, -1
    addi s2, zero, 1
    div s3, a0, zero
    addi s4, zero, 2
    rem s5, a0, zero
    addi s6, zero, 3
    div s7, a4, a5
    addi s8, zero, 4
    rem s9, a4, a5
    CHECK s3, 0xFFFFFFFF, \base+12
    CHECK s5, 0xFEDCBA98, \base+13
    CHECK s7, 0x80000000, \base+14
    CHECK s9, 0x00000000, \base+15

    // The quotient is used by the very next pair, from both slots
    addi t3, zero, 1
    div t4, a1, a2
    add t5, t4, t3
    add t6, t4, a2
    CHECK t4, 0xFFD663CD, \base+16
    CHECK t5, 0xFFD663CE, \base+17
    CHECK t6, 0xFFD663C6, \base+18

    // The same for a product
    addi t3, zero, 1
    mul t4, a2, a1
    add t5, t4, t3
    add t6, t4, a1
    CHECK t4, 0xF8091A2F, \base+19
    CHECK t5, 0xF8091A30, \base+20

    // Two MDU operations side by side: one unit, so they must issue one at a time
    div a4, a1, a2
    mul a5, a0, a1
    mul a6, a0, a1
    div a7, a1, a2
    CHECK a4, 0xFFD663CD, \base+21
    CHECK a5, 0x23E20B28, \base+22
    CHECK a6, 0x23E20B28, \base+23
    CHECK a7, 0xFFD663CD, \base+24

    // A load in slot 0 beside a slot 1 divide: the two units are steered independently
    la t2, mdata
    lw a6, 0(t2)
    divu a7, a1, s11
    CHECK a6, 0x55667788, \base+25
    CHECK a7, 0x00299C33, \base+26

    // A branch in slot 0 must not pair with a slot 1 divide.  Not taken, the divide runs; taken, it
    // must not write.  rd = rs1, so a wrongly committed divide would leave 11 / 7 = 1 behind.
    li s2, 11
    bne zero, zero, 2f
    div s2, s2, s11
2:
    CHECK s2, 1, \base+27
    li s4, 11
    beq zero, zero, 3f
    div s4, s4, s11
3:
    CHECK s4, 11, \base+28

    // A load access fault in slot 0.  The trap flushes the slot 1 divide, the handler skips the
    // load, and the divide then runs on its own.  rd = rs1, so if the flushed copy had also
    // written, the result would be (11 / 7) / 7 = 0 rather than 1.
    li s6, 11
    li a6, 0x90000000
    lw a6, 0(a6)
    div s6, s6, s11
    CHECK s6, 1, \base+29

    // A compressed slot 0 beside a slot 1 divide
    .option push
    .option rvc
    c.li s8, 3
    .option pop
    div s9, a1, a2
    CHECK s8, 3, \base+30
    CHECK s9, 0xFFD663CD, \base+31

    // Operand capture.  A divide holds Execute for many cycles while older instructions drain, so
    // the other instruction of its bundle must keep an operand that was forwarded from the pair just
    // ahead.  First the divide in slot 0 and the consumer in slot 1, then the other way round.
    addi s2, zero, 5
    addi s5, zero, 1
    div  s3, a1, a2
    add  s4, s2, s2
    CHECK s4, 10, \base+32
    CHECK s3, 0xFFD663CD, \base+33
    addi s2, zero, 6
    addi s5, zero, 1
    add  s4, s2, s2
    div  s3, a1, a2
    CHECK s4, 12, \base+34
    CHECK s3, 0xFFD663CD, \base+35

    .option pop
.endm

main:
    li a0, A
    li a1, B
    li a2, C
    li s11, 7

    .align 3
    MDUCASES 0x100

    .align 3
    .option push
    .option norvc
    nop                     // 4 bytes, so every pair of the second pass falls differently in the window
    .option pop
    MDUCASES 0x200

    j pass

.section .tohost
.align 3
tohost:
    .dword 0
fromhost:
    .dword 0

.data
.align 3
mdata:
    .word 0x55667788
