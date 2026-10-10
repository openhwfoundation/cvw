///////////////////////////////////////////
// divflushstall32.S
//
// Written David_Harris@hmc.edu 10/6/26
//
// Purpose: RV32 version of divflushstall for configurations that divide in the integer divider (div.sv,
//          IDIV_ON_FPU = 0).  A divide that the BTB mispredicts as a jump must keep its result when an
//          external stall holds it in Execute as it finishes.  Standalone (WALLY-init-lib.h is RV64 only);
//          the outcome is recorded in selfcheck_record in the WALLY-selfcheck.h format and
//          reported to tohost (1 = pass, 5 = fail).
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

// The dividend is produced two instructions before the divide, so it is forwarded from Writeback when the
// divide starts and is stale in the Execute-stage register afterwards.  A jump at an address that aliases
// the divide in the BTB makes the divide mispredicted.  The testbench stall injector (slti x0, x0, imm with
// imm = {length, delay}) raises ExternalStall; sweeping the delay places the stall on the divide's last cycle.

.option norvc

#define STALL_LEN 3

// a0 = 100 / 7 = 14 (5 / 7 = 0 if the divider restarts with the stale dividend)
.macro TRYDIV dly
.align 6
    li a1, 5                            # stale dividend in the register file
    li a2, 7
    la s1, 1f
    slti x0, x0, (STALL_LEN << 6) | \dly # arm the stall injector
    j traindiv
1:  li s2, 14
    li a3, \dly
    bne a0, s2, fail
.endm

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
    csrci mstatus, 8                    # MIE = 0: no interrupts
    .set d, 0
    .rept 48
    TRYDIV d
    .set d, d+1
    .endr
    la t0, selfcheck_record
    li t1, 1                            # status 1: passed
    sw t1, 0(t0)
    li t0, 1                            # report pass to tohost
    j finish

fail:                                   # status 2: index, address (unused), expected, actual
    la t0, selfcheck_record
    li t1, 2
    sw t1, 0(t0)
    sw a3, 4(t0)
    sw zero, 8(t0)
    sw s2, 12(t0)
    sw a0, 16(t0)
    li t0, (2 << 1) | 1                 # report failure (exit code 2) to tohost

finish:
    la t1, tohost
    sw t0, 0(t1)                        # a store word to tohost ends the simulation
self_loop:
    j self_loop

// BTB aliasing: the BTB index is PC[11:2] (BTB_SIZE = 10), so the jump at traindiv aliases the divide at the
// same offset in divblock.  The jump trains its BTB entry right before the divide runs.
.align 12
trainblock:
    nop
    nop
traindiv:                               # trainblock + 8
    j divseq

.align 12
divblock:
divseq:
    addi a1, zero, 100                  # produce the dividend
    nop
    div a0, a1, a2                      # divblock + 8: aliases traindiv, predicted as a jump
    jr s1

.section .tohost
tohost:
    .word 0
fromhost:
    .word 0

.data
.globl begin_signature
begin_signature:
    .word 0
.globl selfcheck_record
selfcheck_record:
    .fill 8, 4, 0
