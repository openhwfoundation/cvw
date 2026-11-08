///////////////////////////////////////////
// superscalarLateALU32.S
//
// Written: jgong@g.hmc.edu 26 October 2026
//
// Purpose: Self-checking RV32 test for the late ALU.  A slot 1 ALU operation that reads slot 0's
//          result pairs anyway and executes in the Memory stage, where slot 0's result is already
//          registered (issue.sv, datapath.sv).  Each case places a dependent pair and checks:
//            - every base ALU operation the late ALU implements, register and immediate forms
//            - the dependency on rs1, on rs2 and on both
//            - the other operand forwarded from the bundle just ahead, and read from the register file
//            - the late result used by the very next instruction, from slot 0 and from slot 1
//              (LateStall1D), by a branch and by a store
//            - a chain of late pairs, each depending on the last
//            - lui/auipc + addi, the commonest dependent pairs
//            - false dependencies: an immediate or a lui/auipc whose bits name slot 0's rd, which
//              must execute normally rather than take slot 0's result
//            - compressed instructions in either slot
//            - slot 0 writing x0, which is no dependency at all
//            - dependent pairs the late ALU must refuse (slot 0 load, slot 1 load) still computing
//              correctly as single issue
//            - both slots writing the same register, with ALU, load and multiply in either slot: the
//              younger slot 1 value must win through every forwarding path and the register file
//          Pairing depends on where the two instructions fall in the fetch window, so every case is
//          run twice, the second time shifted by 4 bytes.  The testbench's "slot1 late" count shows
//          how many actually ran on the late ALU.  A failing check stores (index << 1) | 1 to tohost.
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

// Operands: a0 = A, a1 = B, a2 = C.  t0, t1 and t2 are reserved for CHECK and the trap handler.
#define A 0xFEDCBA98
#define B 0x01234567
#define C 0xFFFFFFF9

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

.macro LATECASES base
    .option push
    .option norvc

    // Register-register operations, slot 1 reading slot 0's result as rs1
    addi s2, a0, 1          // s2 = A + 1 = 0xFEDCBA99
    add  s3, s2, a1         // s3 = 0xFEDCBA99 + 0x01234567
    addi s4, a0, 1
    sub  s5, s4, a1
    addi s6, a1, 0
    sll  s7, s6, a2         // shift by C[4:0] = 25
    addi s8, a0, 0
    slt  s9, s8, a1         // A is negative
    CHECK s3, 0x00000000, \base+1
    CHECK s5, 0xFDB97532, \base+2
    CHECK s7, 0xCE000000, \base+3
    CHECK s9, 1, \base+4

    addi s2, a0, 0
    sltu s3, s2, a1
    addi s4, a0, 0
    xor  s5, s4, a1
    addi s6, a0, 0
    srl  s7, s6, a2
    addi s8, a0, 0
    sra  s9, s8, a2
    CHECK s3, 0, \base+5
    CHECK s5, 0xFFFFFFFF, \base+6
    CHECK s7, 0x0000007F, \base+7
    CHECK s9, 0xFFFFFFFF, \base+8

    addi s2, a0, 0
    or   s3, s2, a1
    addi s4, a0, 0
    and  s5, s4, a1
    CHECK s3, 0xFFFFFFFF, \base+9
    CHECK s5, 0x00000000, \base+10

    // ... as rs2, which matters for sub, the shifts and slt
    addi s2, a1, 0
    sub  s3, a0, s2
    addi s4, zero, 4
    sll  s5, a1, s4
    addi s6, zero, 4
    sra  s7, a0, s6
    addi s8, a0, 0
    slt  s9, a1, s8
    CHECK s3, 0xFDB97531, \base+11
    CHECK s5, 0x12345670, \base+12
    CHECK s7, 0xFFEDCBA9, \base+13
    CHECK s9, 0, \base+14

    // ... as both operands
    addi s2, a1, 1
    add  s3, s2, s2
    addi s4, a1, 0
    sub  s5, s4, s4
    addi s6, a1, 0
    xor  s7, s6, s6
    addi s8, zero, 3
    sll  s9, s8, s8
    CHECK s3, 0x02468AD0, \base+15
    CHECK s5, 0, \base+16
    CHECK s7, 0, \base+17
    CHECK s9, 24, \base+18

    // Immediate operations
    addi s2, a0, 0
    addi s3, s2, -0x98
    addi s4, a0, 0
    slti s5, s4, 0
    addi s6, a0, 0
    sltiu s7, s6, -1
    addi s8, a0, 0
    xori s9, s8, -1
    CHECK s3, 0xFEDCBA00, \base+19
    CHECK s5, 1, \base+20
    CHECK s7, 1, \base+21
    CHECK s9, 0x01234567, \base+22

    addi s2, a0, 0
    ori  s3, s2, 0x7FF
    addi s4, a0, 0
    andi s5, s4, 0x0F0
    addi s6, a1, 0
    slli s7, s6, 8
    addi s8, a0, 0
    srli s9, s8, 8
    CHECK s3, 0xFEDCBFFF, \base+23
    CHECK s5, 0x00000090, \base+24
    CHECK s7, 0x23456700, \base+25
    CHECK s9, 0x00FEDCBA, \base+26
    addi s2, a0, 0
    srai s3, s2, 8
    CHECK s3, 0xFFFEDCBA, \base+27

    // lui + addi and auipc + addi, the pairs compilers emit for constants and addresses
    lui  s2, 0x12345
    addi s3, s2, 0x678
    CHECK s3, 0x12345678, \base+28
    lui  s4, 0xFEDCC
    addi s5, s4, -0x568
    CHECK s5, 0xFEDCBA98, \base+29
1:  auipc s6, 0
    addi  s7, s6, 12
    la    s8, 1b
    addi  s8, s8, 12
    bne   s7, s8, 2f
    j 3f
2:  li t1, ((\base+30) << 1) | 1
    j fail
3:

    // The other operand comes from the bundle just ahead: from slot 0 and from slot 1 of it
    addi s4, a1, 0          // s4 = B, written one bundle ahead
    addi s5, zero, 3
    addi s2, a0, 0
    add  s3, s2, s4         // s2 late from slot 0, s4 forwarded
    addi s6, zero, 1
    sll  s7, s6, s5
    CHECK s3, 0xFFFFFFFF, \base+31
    CHECK s7, 8, \base+32

    // The late result read by the very next instruction, whichever slot it lands in
    addi s2, a0, 0
    addi s3, s2, 1
    addi s4, s3, 1          // reads the late result; LateStall1D holds it until Result1W
    addi s5, s3, 2
    CHECK s4, 0xFEDCBA9A, \base+33
    CHECK s5, 0xFEDCBA9B, \base+34
    addi s2, a0, 0
    addi s3, s2, 1
    addi s6, zero, 5        // independent slot 0 ...
    add  s7, s3, s6         // ... beside a slot 1 that reads the late result
    CHECK s7, 0xFEDCBA9E, \base+35

    // A chain of late pairs, each reading the one before
    addi s2, zero, 1
    slli s3, s2, 4
    addi s4, s3, 1
    slli s5, s4, 4
    addi s6, s5, 1
    slli s7, s6, 4
    addi s8, s7, 1
    slli s9, s8, 4
    CHECK s9, 0x11110, \base+36

    // A branch and a store reading the late result
    addi s2, a0, 0
    addi s3, s2, 0x168      // 0xFEDCBA98 + 0x168 = 0xFEDCBC00
    li   s4, 0xFEDCBC00
    beq  s3, s4, 1f
    li   t1, ((\base+37) << 1) | 1
    j    fail
1:  la   s6, ldata
    addi s2, a1, 0
    xori s3, s2, -1
    sw   s3, 0(s6)
    lw   s7, 0(s6)
    CHECK s7, 0xFEDCBA98, \base+38

    // False dependencies.  The immediate's low bits name s2 (x18) in rs2's field, and lui's and
    // auipc's immediate bits name it in rs1's: none of them reads s2, so none may take slot 0's result.
    addi s2, zero, 1
    addi s3, a1, 18         // [24:20] = 18 = s2
    CHECK s3, 0x01234579, \base+39
    addi s2, zero, 1
    lui  s3, 0x90           // [19:15] = 0b10010 = s2
    CHECK s3, 0x00090000, \base+40

    // Slot 0 writing x0 creates no dependency on x0
    addi zero, a0, 1
    add  s3, zero, a1
    CHECK s3, 0x01234567, \base+41

    // Dependent pairs the late ALU must refuse still compute correctly as single issue
    la   s6, ldata2
    lw   s2, 0(s6)
    addi s3, s2, 1          // slot 0 is a load: its result is too late for the Memory stage
    addi s4, s6, 4
    lw   s5, -4(s4)         // slot 1 load whose address depends on slot 0
    CHECK s3, 0x55667789, \base+42
    CHECK s5, 0x55667788, \base+43

    .option pop

    // Compressed instructions, in either slot.  The two-address forms (c.add, c.sub, ...) write the
    // register they read, so the dependent one names a different rd from slot 0's.  c.mv and c.add use
    // the full register set; c.sub uses x8-x15.
    .option push
    .option rvc
    c.li a5, 1
    mv   a3, a0             // c.mv in slot 0 ...
    c.add a5, a3            // ... compressed dependent slot 1: a5 = 1 + A
    addi a4, a1, 0          // 32-bit slot 0 ...
    c.mv s1, a4             // ... compressed dependent slot 1
    CHECK a5, 0xFEDCBA99, \base+44
    CHECK s1, 0x01234567, \base+45
    c.li a5, 2
    c.li a4, 3
    c.add a5, a4            // a5 = 5
    c.li a4, 2
    c.sub s1, a4            // s1 = B - 2
    CHECK a5, 5, \base+46
    CHECK s1, 0x01234565, \base+47
    .option pop

    // Both slots writing the same register.  Slot 1 is younger, so its value must be the one every
    // later reader sees: forwarded from Memory, from Writeback, or read from the register file.
    .option push
    .option norvc
    addi s2, a0, 1
    addi s2, s2, 1          // late and same rd
    add  s3, s2, zero       // read straight away, from slot 0 of the next bundle
    CHECK s3, 0xFEDCBA9A, \base+48
    addi s2, zero, 5
    addi s2, zero, 7        // independent, same rd
    addi s3, s2, 1          // forwarded from Memory
    addi s4, zero, 0
    addi s5, s2, 2          // ... and into slot 1
    CHECK s3, 8, \base+49
    CHECK s5, 9, \base+50
    addi s2, zero, 5
    addi s2, zero, 7
    addi s4, zero, 0
    addi s5, zero, 0
    addi s3, s2, 1          // forwarded from Writeback
    CHECK s3, 8, \base+51
    CHECK s2, 7, \base+52   // from the register file by now
    la   s6, ldata2
    lw   s2, 0(s6)          // slot 0 load ...
    addi s2, zero, 9        // ... overwritten by slot 1: the load's stall must not resurrect it
    addi s3, s2, 0
    CHECK s3, 9, \base+53
    addi s2, zero, 3
    lw   s2, 0(s6)          // slot 1 load overwrites slot 0's ALU result
    addi s3, s2, 1
    CHECK s3, 0x55667789, \base+54
    mul  s2, a2, a2         // slot 0 multiply ...
    addi s2, zero, 4        // ... overwritten by slot 1
    addi s3, s2, 0
    CHECK s3, 4, \base+55
    addi s2, zero, 6
    mul  s2, a2, a2         // slot 1 multiply overwrites slot 0: C * C = 49
    addi s3, s2, 0
    CHECK s3, 49, \base+56
    addi s2, a0, 0
    xori s2, s2, -1         // late, same rd: s2 = B
    addi s7, zero, 0
    add  s8, s2, a1         // read from slot 1 of the next bundle
    CHECK s8, 0x02468ACE, \base+57

    // Slot 1 reading a result the bundle just ahead produced too late to forward: it goes late and
    // takes the value from Writeback instead of stalling.  Each producer sits in slot 1 of its bundle
    // on one pass and in slot 0 on the other.
    la   s6, ldata2
    addi s3, zero, 0
    lw   s2, 0(s6)          // load ...
    addi s4, zero, 1
    addi s5, s2, 1          // ... read by slot 1 of the next bundle
    CHECK s5, 0x55667789, \base+58
    addi s3, zero, 0
    mul  s2, a2, a2         // multiply: C * C = 49 ...
    addi s4, zero, 1
    addi s5, s2, 1          // ... read by slot 1 of the next bundle
    CHECK s5, 50, \base+59
    addi s2, a0, 0
    addi s3, s2, 1          // late slot 1 ...
    addi s4, zero, 1
    addi s5, s3, 1          // ... read by a slot 1 that is late in turn
    CHECK s5, 0xFEDCBA9A, \base+60
    lw   s2, 0(s6)
    addi s3, zero, 0
    addi s4, a1, 0
    add  s5, s4, s2         // one operand from slot 0 of its own bundle, the other from the load
    CHECK s5, 0x5689BCEF, \base+61
    lw   s2, 0(s6)
    addi s3, zero, 0
    addi s4, zero, 1
    add  s5, s2, s2         // both operands from the load
    CHECK s5, 0xAACCEF10, \base+62
    addi s3, zero, 0
    lw   s2, 0(s6)
    div  s3, a0, a2         // a divide holds Execute while the load retires: the operand must be
    addi s5, s2, 1          // ... picked up by operand capture, not from a Writeback it has left
    CHECK s5, 0x55667789, \base+63
    CHECK s3, 0x00299C33, \base+64
    csrw mscratch, a1
    csrr s2, mscratch       // CSR read: its value appears in Writeback
    addi s4, zero, 1
    addi s5, s2, 1
    CHECK s5, 0x01234568, \base+65
    addi s3, zero, 0
    lw   s2, 0(s6)
    addi s2, zero, 7        // slot 0 overwrites the loaded register: slot 1 must see 7, not the load
    addi s5, s2, 1
    CHECK s5, 8, \base+66
    .option pop
.endm

main:
    li a0, A
    li a1, B
    li a2, C

    .align 3
    LATECASES 0x100

    .align 3
    .option push
    .option norvc
    nop                     // 4 bytes, so every pair of the second pass falls differently in the window
    .option pop
    LATECASES 0x200

    j pass

.section .tohost
.align 3
tohost:
    .dword 0
fromhost:
    .dword 0

.data
.align 3
ldata:
    .word 0
ldata2:
    .word 0x55667788
