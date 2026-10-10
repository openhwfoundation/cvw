///////////////////////////////////////////
// vm64check.S
//
// Written: David_Harris@hmc.edu 7 April 2023
//
// Purpose: vm64check coverage
//          Self-checking (WALLY-selfcheck.h).  Every jump runs in machine mode, so its target is
//          used untranslated and lies outside every memory region: the fetch must take an
//          instruction access fault (mcause 1) with mepc = mtval = the target.  vmtrap records
//          mcause, mepc and mtval in s10, s9 and s11 and returns to ra; each check compares
//          them.  Every other trap but an ecall fails the test.  Failure indices: 10 * jump number
//          + 1 mcause, + 2 mepc, + 3 mtval; 0xF0 any other trap.
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

// Cover IMMU vm64check block by jumping to illegal virtual addresses
// Need a nonstandard trap handler to deal with returns from these jumps
//    assign eq_46_38 = &(VAdr[46:38]) | ~|(VAdr[46:38]);
 //   assign eq_63_47 = &(VAdr[63:47]) | ~|(VAdr[63:47]);
 //   assign UpperBitsUnequal = SV39Mode ? ~(eq_63_47 & eq_46_38) : ~eq_63_47;

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// FAULTED n: the jump to the address in t0 took an instruction access fault there (n = jump number)
.macro FAULTED n
    li t2, 1
    SC_CHECK_EQ s10, t2, 10 * \n + 1
    SC_CHECK_EQ s9, t0, 10 * \n + 2
    SC_CHECK_EQ s11, t0, 10 * \n + 3
    li s10, -1                  # no trap recorded for the next jump yet
.endm

main:
    la t0, vmtrap
    csrw mtvec, t0
    li s10, -1

    # SATP in non-39 mode
    csrw satp, zero

    // vm64check coverage
check1:
    // check virtual addresses with bits 63:47 and/or 46:38 being equal or unequal
    li t0, 0x00000001800F0000   # unimplemented memory with upper and lower all zero
    la ra, check2
    jalr t0

check2:
    FAULTED 1
    li t0, 0xFFFFFFF1800F0000   # unimplemented memory with upper and lower all one
    la ra, check3
    jalr t0

check3:
    FAULTED 2
    li t0, 0xFFF81001800F0000   # unimplemented memory with upper all one, lower mixed
    la ra, check4
    jalr t0

check4:
    FAULTED 3
    li t0, 0x03001001800F0000   # unimplemented memory with upper mixed, lower mixed
    la ra, check5
    jalr t0

check5:
    FAULTED 4
    li t0, 0x00001001800F0000   # unimplemented memory with upper all zero, lower mixed
    la ra, check11
    jalr t0

check11:
    FAULTED 5
    # SATP in SV39 mode
    li t0, 0x8000000000000000
    csrw satp, t0

    // check virtual addresses with bits 63:47 and/or 46:38 being equal or unequal
    li t0, 0x00000001800F0000   # unimplemented memory with upper and lower all zero
    la ra, check12
    jalr t0

check12:
    FAULTED 6
    li t0, 0xFFFFFFF1800F0000   # unimplemented memory with upper and lower all one
    la ra, check13
    jalr t0

check13:
    FAULTED 7
    li t0, 0xFFF81001800F0000   # unimplemented memory with upper all one, lower mixed
    la ra, check14
    jalr t0

check14:
    FAULTED 8
    li t0, 0x03001001800F0000   # unimplemented memory with upper mixed, lower mixed
    la ra, check15
    jalr t0

check15:
    FAULTED 9
    li t0, 0x00001001800F0000   # unimplemented memory with upper all zero, lower mixed
    la ra, check15a
    jalr t0

    # The checks above leave three SV39 FEC terms in vm64check uncovered because no
    # VA exercises these exact upper-bit field patterns.  Add them explicitly:
check15a:                       # all0_55_47_0: bits[63:56]=0, bits[55:47]!=0 (bit47), bits[46:38]=0
    FAULTED 10
    li t0, 0x00008000800F0000
    la ra, check15b
    jalr t0

check15b:                       # all1_46_38_0: bits[63:47]=all1, bits[46:38]!=all1 (=0)
    FAULTED 11
    li t0, 0xFFFF8000800F0000
    la ra, check15c
    jalr t0

check15c:                       # all1_55_47_0: bits[63:56]=all1, bits[55:47]!=all1 (=0), bits[46:38]=all1
    FAULTED 12
    li t0, 0xFF007FC0800F0000
    la ra, check16
    jalr t0

check16:
    FAULTED 13
    SC_PASS
    j done

// Instruction access faults: record mcause in s10, mepc in s9 and mtval in s11 and return to ra.  Everything
// else goes to sc_trap_handler, which passes ecalls on to the WALLY-init-lib.h handler and fails the test on
// any other trap.
.align 4                # trap handlers must be aligned to multiple of 4
vmtrap:
    csrr s10, mcause
    addi s8, s10, -1
    bnez s8, sc_trap_handler
    csrr s9, mepc
    csrr s11, mtval
    csrw mepc, ra       # return to address in ra
    mret
