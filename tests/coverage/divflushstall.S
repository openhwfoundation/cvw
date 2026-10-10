///////////////////////////////////////////
// divflushstall.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: A divide that the BTB mispredicts as a jump must keep its result when an external stall holds
//          it in Execute as it finishes.  The flush for the misprediction must not restart the divider,
//          which would recompute with the stale (no longer forwarded) operand.
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

// The dividend is produced two instructions before the divide, so it is forwarded from Writeback when the
// divide starts and is stale in the Execute-stage register afterwards.  A jump at an address that aliases
// the divide in the BTB makes the divide mispredicted.  The testbench stall injector (slti x0, x0, imm with
// imm = {length, delay}) raises ExternalStall; sweeping the delay places the stall on the divide's last cycle.

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

.option norvc

#define STALL_LEN 3

// integer divide: a0 = 100 / 7 = 14 (5 / 7 = 0 if it restarts with the stale dividend)
.macro TRYDIV dly
.align 6
    li a1, 5                            # stale dividend in the register file
    li a2, 7
    la s1, 1f
    slti x0, x0, (STALL_LEN << 6) | \dly # arm the stall injector
    j traindiv
1:  li s2, 14
    SC_CHECK_EQ a0, s2, \dly
.endm

// fdiv.d: f3 = -6.0 / 2.0 = -3.0 (+3.0 if it uses the stale dividend's sign)
.macro TRYFDIV dly
.align 6
    fmv.d.x f1, s3                      # stale dividend (+6.0) in the register file
    la s1, 1f
    slti x0, x0, (STALL_LEN << 6) | \dly
    j trainfdiv
1:  fmv.x.d a0, f3
    SC_CHECK_EQ a0, s5, 100 + \dly
.endm

main:
    csrci mstatus, 8                    # MIE = 0: no interrupts
    li t0, 0x2000
    csrs mstatus, t0                    # mstatus.FS = Initial
    li s3, 0x4018000000000000           # +6.0
    li s4, 0xC018000000000000           # -6.0
    li t0, 0x4000000000000000           # 2.0
    fmv.d.x f2, t0
    li s5, 0xC008000000000000           # -3.0

    .set d, 0
    .rept 48
    TRYDIV d
    .set d, d+1
    .endr

    .set d, 0
    .rept 48
    TRYFDIV d
    .set d, d+1
    .endr

    SC_PASS
    j done

// BTB aliasing: the BTB index is PC[11:2] (BTB_SIZE = 10), so the jumps in trainblock alias the divides at
// the same offsets in divblock and fdivblock.  Each jump trains its BTB entry right before its divide runs.
.align 12
trainblock:
    nop
    nop
traindiv:                               # trainblock + 8
    j divseq
    nop
trainfdiv:                              # trainblock + 16
    j fdivseq

.align 12
divblock:
divseq:
    addi a1, zero, 100                  # produce the dividend
    nop
    div a0, a1, a2                      # divblock + 8: aliases traindiv, predicted as a jump
    jr s1

.align 12
fdivblock:
    nop
    nop
fdivseq:
    fmv.d.x f1, s4                      # produce the dividend (-6.0)
    nop
    fdiv.d f3, f1, f2                   # fdivblock + 16: aliases trainfdiv, predicted as a jump
    jr s1
