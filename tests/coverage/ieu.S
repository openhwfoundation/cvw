///////////////////////////////////////////
// ieu.S
//
// Written: David_Harris@hmc.edu 21 March 2023
//
// Purpose: Test coverage for IEU
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

main:

    # Division test (having trouble with buildroot)
    li x11, 0x384000
    li x12, 0x1c2000
    divuw x9, x11, x12

    # Test clz with all bits being 0
    li t0, 0
    clz t1, t0
    li t0, -1
    clz t1, t0
    li t0, 1
    clz t1, t0

    # Test forwarding from store conditional
    mv a0, sp
    lr.w t0, 0(a0)
    sc.w t0, a1, 0(a0)
    addi t0, t0, 1

    # test prefetch Hints (ori with destination x0)
    ori x0, x0, 0
    ori x0, x0, 1
    ori x0, x0, 2
    ori x0, x0, 3


    # Test illegal instructions are detected
    .word 0x80000033 // illegal R-type instruction
    .word 0x00007003 // illegal Load instruction
    .word 0x80005013 // illegal I-type instruction: srli: op = 0010011, funct3 = 101, funct7 = 1000000
    .word 0x00000000 // illegal instruction
    .word 0x0000701B  // Illegal IW instruction
    .word 0x00004023  // Illegal store instruction
    .word 0x0400003B  // Illegal RW or MulDivW instruction
    .word 0x00007067  // Illegal JALR instruction
    .word 0x00002063  // Illegal branch instruction
    .word 0x60F01013  // Illegal BMU sign extend / count instruction
    .word 0x60801013  // Illegal BMU sign extend / count instruction
    .word 0x60301013  // Illegal BMU sign extend / count instruction
    .word 0x6BF05013  // Illegal BMU similar to rev8
    .word 0x69805013  // Illegal BMU similar to rev8
    .word 0x28F05013  // Illegal BMU similar to or.c
    .word 0x60F0101B  // Illegal BMU similar to count word
    .word 0x6080101B  // Illegal BMU similar to count word
    .word 0x6030101B  // Illegal BMU similar to count word
    .word 0x0000202F  // Illegal similar to LR
    .word 0x1010202F  // Illegal similar to LR
    .word 0x00402003  // illegal similar to CMO
    .word 0x00202003  // illegal similar to CMO
    .word 0xFF00302F  // illegal Atomic instruction
    .word 0xFF00402F  // illegal Atomic instruction
    .word 0x00000873  // illegal CSR instruction
    .word 0x31bf1f93  // illegal aes64ksli1 instruction

    # Illegal CMO instructions because envcfg is 0 and system is in user Mode
    li a0, 0
    ecall # switch to user mode
    cbo.inval (x1)
    cbo.clean (x1)
    cbo.flush (x1)
    cbo.zero  (x1)

    li a0, 3
    ecall # switch back to machine mode
    li x1, 0x50
    csrw menvcfg, x1
    csrw senvcfg, x1
    li a0, 0
    ecall # switch to user mode
    cbo.inval (x2)
    cbo.clean (x3)
    cbo.flush (x1)




    j done
