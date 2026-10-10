///////////////////////////////////////////
// csrwrites.S
//
// Written: David_Harris@hmc.edu 21 March 2023
//
// Purpose: Test writes to CSRs
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
//
// Checks: stimecmp, satp, stvec and sscratch read back what was written; menvcfg and senvcfg
// legalize an all-ones-but-FIOM write to the fields rv64gc implements (STCE, PBMTE, ADUE, CBZE,
// CBCFE, CBIE); each FIOM set and clear reads back (failure indices 1-10).  Writing the read-only
// time CSR is an illegal instruction, and each ecall reports the privilege mode the previous one
// switched to (8 = U, 9 = S, 11 = M), checked in a trap log (indices 0x100-0x1FF).  FIOM itself has
// no visible effect on Wally because its fences do nothing.

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// menvcfg: STCE, PBMTE, ADUE, CBZE, CBCFE, CBIE = 11
#define MENVCFG_LEGAL 0xE0000000000000F0
// senvcfg: CBZE, CBCFE, CBIE = 11
#define SENVCFG_LEGAL 0xF0

// CHECK_CSR csr, expected, index: fail with index unless the CSR reads expected
.macro CHECK_CSR csr, expected, index
    csrr a1, \csr
    li a2, \expected
    SC_CHECK_EQ a1, a2, \index
.endm

main:
    la t0, log_trap
    csrw mtvec, t0

    li t0, -5
    csrw stimecmp, t0   # initialize so ImperasDV agrees
    csrrw a1, stimecmp, t0
    li a2, -5
    SC_CHECK_EQ a1, a2, 1
    csrrw a1, satp, zero
    csrrw a1, stvec, zero
    csrrw a1, sscratch, zero
    CHECK_CSR stimecmp, -5, 2
    CHECK_CSR satp, 0, 3
    CHECK_CSR stvec, 0, 4
    CHECK_CSR sscratch, 0, 5
    li t0, -2
    csrrw a3, menvcfg, t0
    csrrw a4, senvcfg, t0
    CHECK_CSR menvcfg, MENVCFG_LEGAL, 6
    CHECK_CSR senvcfg, SENVCFG_LEGAL, 7

    # Test writing to TIME CSR
ill_time:
    csrw time, zero

    # testing FIOM with different privilege modes
    # setting environment config (to both 1 and 0) in each privilege mode
    csrsi menvcfg, 1
    CHECK_CSR menvcfg, MENVCFG_LEGAL | 1, 8
    li a0, 1
ecall_m1:
    ecall               # enter supervisor mode

    li a0, 0
ecall_s1:
    ecall               # enter user mode

    li a0, 1
ecall_u1:
    ecall               # enter supervisor mode

    csrsi senvcfg, 1
    CHECK_CSR senvcfg, SENVCFG_LEGAL | 1, 9
    li a0, 0
ecall_s2:
    ecall               # enter user mode

    li a0, 3
ecall_u2:
    ecall               # enter machine mode
    csrci menvcfg, 1
    CHECK_CSR menvcfg, MENVCFG_LEGAL, 10

    li a0, 1
ecall_m2:
    ecall               # enter supervisor mode

    li a0, 0
ecall_s3:
    ecall               # enter user mode

    li a0, 3
ecall_u3:
    ecall               # back to machine mode to check the trap log
    jal check_traps
    SC_PASS
    j done

// Trap log: log_trap records mcause, mepc and mtval of every trap, then continues in the
// WALLY-init-lib.h handler, which handles ecalls and skips other faulting instructions.  check_traps
// compares the log with expected_traps, failing with index 0x100 + 3n + k for field k (0 = mcause,
// 1 = mepc, 2 = mtval) of trap n, or 0x1FF if the number of traps differs.
.equ TRAPLOG_MAX, 16
.align 4
log_trap:
    csrrw t0, mscratch, t0          # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    sd t2, -24(t0)
    sd t3, -32(t0)
    la t1, traplog
    ld t2, 0(t1)
    addi t2, t2, 1                  # count the trap
    sd t2, 0(t1)
    li t1, TRAPLOG_MAX
    bgtu t2, t1, 1f                 # log full: count only
    slli t3, t2, 4
    slli t2, t2, 3
    add t2, t2, t3
    la t1, traplog - 16
    add t1, t1, t2                  # trap n (from 1) goes at traplog + 24n - 16
    csrr t2, mcause
    sd t2, 0(t1)
    csrr t2, mepc
    sd t2, 8(t1)
    csrr t2, mtval
    sd t2, 16(t1)
1:  ld t3, -32(t0)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0          # restore t0 and the trap stack pointer
    j trap_handler

check_traps:
    la a1, traplog + 8
    la a2, expected_traps
    ld a3, 0(a2)
    addi a2, a2, 8
    slli a4, a3, 1
    add a3, a3, a4                  # fields to compare
    li a4, 0x100
1:  beqz a3, 2f
    ld a5, 0(a1)                    # actual
    ld a6, 0(a2)                    # expected
    bne a5, a6, 3f
    addi a1, a1, 8
    addi a2, a2, 8
    addi a3, a3, -1
    addi a4, a4, 1
    j 1b
2:  la a1, traplog                  # and no extra traps
    ld a5, 0(a1)
    la a2, expected_traps
    ld a6, 0(a2)
    li a4, 0x1FF
    bne a5, a6, 3f
    ret
3:  la t0, selfcheck_record         # record the mismatch as SC_CHECK_EQ does
    li t1, 2
    sd t1, 0(t0)
    sd a4, 8(t0)
    sd zero, 16(t0)
    sd a6, 24(t0)
    sd a5, 32(t0)
    SC_REPORT_FAIL
    j done

.section .data
.align 3
traplog:                            # number of traps, then mcause, mepc and mtval of each
    .fill 1 + 3*TRAPLOG_MAX, 8, 0
expected_traps:                     # number of traps, then mcause, mepc and mtval of each
    .dword (2f - 1f) / 24
1:  .dword 2, ill_time, 0xc0101073          # illegal instruction: time is read-only
    .dword 11, ecall_m1, 0                  # ecall from M
    .dword 9, ecall_s1, 0                   # ecall from S
    .dword 8, ecall_u1, 0                   # ecall from U
    .dword 9, ecall_s2, 0
    .dword 8, ecall_u2, 0
    .dword 11, ecall_m2, 0
    .dword 9, ecall_s3, 0
    .dword 8, ecall_u3, 0
2:
