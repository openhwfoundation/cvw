///////////////////////////////////////////
// ieu.S
//
// Written: David_Harris@hmc.edu 21 March 2023
//
// Purpose: Test coverage for IEU
//          Checks the divide, clz, and store conditional results, that the prefetch hints do
//          not trap, and the cause and address of the trap each illegal or faulting instruction
//          raises, in machine mode and (through record_trap) in user mode.
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

// EXPECT cause, index, insn: run insn and check that it raised exactly one trap, with mcause = cause,
// at its own address.  record_trap counts traps and saves mcause and mepc in lasttrap, so this works
// in user mode, which cannot read mcause.  Clobbers s2, t2-t4.
.macro EXPECT cause, index, insn:vararg
    la t2, lasttrap
    ld s2, 16(t2)           # trap count before
1:
    \insn
    la t2, lasttrap
    ld t3, 16(t2)
    sub t3, t3, s2
    li t4, 1
    SC_CHECK_EQ t3, t4, \index
    ld t3, 0(t2)
    li t4, \cause
    SC_CHECK_EQ t3, t4, \index + 1
    ld t3, 8(t2)
    la t4, 1b
    SC_CHECK_EQ t3, t4, \index + 2
.endm

// NOTRAP index, insn: run insn and check that it did not trap
.macro NOTRAP index, insn:vararg
    la t2, lasttrap
    ld s2, 16(t2)
    \insn
    la t2, lasttrap
    ld t3, 16(t2)
    SC_CHECK_EQ t3, s2, \index
.endm

main:
    la t0, record_trap
    csrw mtvec, t0

    # Division test (having trouble with buildroot)
    li x11, 0x384000
    li x12, 0x1c2000
    divuw x9, x11, x12
    li t2, 2
    SC_CHECK_EQ x9, t2, 1   # 0x384000 / 0x1c2000 = 2

    # Test clz with all bits being 0
    li t0, 0
    clz a2, t0
    li t0, -1
    clz a3, t0
    li t0, 1
    clz a4, t0
    li t2, 64
    SC_CHECK_EQ a2, t2, 2   # clz(0) = XLEN
    SC_CHECK_EQ a3, zero, 3 # clz(-1) = 0
    li t2, 63
    SC_CHECK_EQ a4, t2, 4   # clz(1) = 63

    # Test forwarding from store conditional
    mv a0, sp
    lr.w t0, 0(a0)
    sc.w t0, a1, 0(a0)
    addi a5, t0, 1          # uses the sc.w result in the next instruction
    li t2, 1
    SC_CHECK_EQ a5, t2, 5   # sc.w succeeded (wrote 0), and the addi saw it
    lw t3, 0(a0)
    SC_CHECK_EQ t3, a1, 6   # sc.w stored a1 (x11, 0x384000 from the division test)

    # test prefetch Hints (ori with destination x0); hints must not trap
    la t2, lasttrap
    ld s2, 16(t2)
    ori x0, x0, 0
    ori x0, x0, 1
    ori x0, x0, 2
    ori x0, x0, 3
    la t2, lasttrap
    ld t3, 16(t2)
    SC_CHECK_EQ t3, s2, 7

    # Test illegal instructions are detected (mcause 2).  Some of these encodings are legal
    # instructions that fault on address 0 instead, as noted.
    EXPECT 2, 10,  .word 0x80000033 // illegal R-type instruction
    EXPECT 2, 13,  .word 0x00007003 // illegal Load instruction
    EXPECT 2, 16,  .word 0x80005013 // illegal I-type instruction: srli: op = 0010011, funct3 = 101, funct7 = 1000000
    // illegal instruction 0x00000000: two 16-bit all-zero instructions, each illegal
    EXPECT 2, 19,  .2byte 0x0000
    EXPECT 2, 22,  .2byte 0x0000
    EXPECT 2, 25,  .word 0x0000701B  // Illegal IW instruction
    EXPECT 2, 28,  .word 0x00004023  // Illegal store instruction
    EXPECT 2, 31,  .word 0x0400003B  // Illegal RW or MulDivW instruction
    EXPECT 2, 34,  .word 0x00007067  // Illegal JALR instruction
    EXPECT 2, 37,  .word 0x00002063  // Illegal branch instruction
    EXPECT 2, 40,  .word 0x60F01013  // Illegal BMU sign extend / count instruction
    EXPECT 2, 43,  .word 0x60801013  // Illegal BMU sign extend / count instruction
    EXPECT 2, 46,  .word 0x60301013  // Illegal BMU sign extend / count instruction
    EXPECT 2, 49,  .word 0x6BF05013  // Illegal BMU similar to rev8
    EXPECT 2, 52,  .word 0x69805013  // Illegal BMU similar to rev8
    EXPECT 2, 55,  .word 0x28F05013  // Illegal BMU similar to or.c
    EXPECT 2, 58,  .word 0x60F0101B  // Illegal BMU similar to count word
    EXPECT 2, 61,  .word 0x6080101B  // Illegal BMU similar to count word
    EXPECT 2, 64,  .word 0x6030101B  // Illegal BMU similar to count word
    EXPECT 7, 67,  .word 0x0000202F  // amoadd.w x0, x0, (x0): legal, but no memory at 0 -> store/AMO access fault
    EXPECT 2, 70,  .word 0x1010202F  // Illegal similar to LR (lr.w with rs2 != 0)
    EXPECT 5, 73,  .word 0x00402003  // lw x0, 4(x0): legal, but no memory at 4 -> load access fault
    EXPECT 5, 76,  .word 0x00202003  // lw x0, 2(x0): misaligned loads are supported (Zicclsm) -> load access fault
    EXPECT 2, 79,  .word 0xFF00302F  // illegal Atomic instruction
    EXPECT 2, 82,  .word 0xFF00402F  // illegal Atomic instruction
    EXPECT 2, 85,  .word 0x00000873  // illegal CSR instruction (ecall encoding with rd != 0)
    EXPECT 2, 88,  .word 0x31bf1f93  // illegal aes64ksli1 instruction (rnum = 0xB > 0xA)

    # Illegal CMO instructions because envcfg is 0 and system is in user Mode
    li a0, 0
    ecall # switch to user mode
    EXPECT 2, 100, cbo.inval 0(x1)
    EXPECT 2, 103, cbo.clean 0(x1)
    EXPECT 2, 106, cbo.flush 0(x1)
    EXPECT 2, 109, cbo.zero 0(x1)

    li a0, 3
    ecall # switch back to machine mode
    li x1, 0x50
    csrw menvcfg, x1        # CBCFE = 1, CBIE = 01 (cbo.inval performs a flush); CBZE = 0
    csrw senvcfg, x1
    li x3, 0                # x3 (gp) is 0 from reset; set it explicitly since cbo.clean uses it as the address
    li a0, 0
    ecall # switch to user mode
    NOTRAP 112, cbo.inval 0(x2)          # sp is ordinary RAM
    EXPECT 7, 113, cbo.clean 0(x3)       # no memory at 0 -> store/AMO access fault
    EXPECT 7, 116, cbo.flush 0(x1)       # no memory at 0x50 -> store/AMO access fault

    # Every trap is accounted for: 27 in the illegal list above, 4 + 2 cbo traps, and 3 ecalls
    la t2, lasttrap
    ld t3, 16(t2)
    li t4, 36
    SC_CHECK_EQ t3, t4, 120

    SC_PASS
    j done

// Record mcause and mepc in lasttrap and count the trap, then continue in the library trap handler
.align 4
record_trap:
    csrrw t0, mscratch, t0      # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    sd t2, -24(t0)
    la t1, lasttrap
    csrr t2, mcause
    sd t2, 0(t1)
    csrr t2, mepc
    sd t2, 8(t1)
    ld t2, 16(t1)
    addi t2, t2, 1
    sd t2, 16(t1)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0      # restore t0 and the trap stack pointer
    j trap_handler

.section .data
.align 3
lasttrap:               # mcause, mepc, and number of traps
    .fill 3, 8, 0
