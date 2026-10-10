///////////////////////////////////////////
// wfitimeout.S
//
// Written: David_Harris@hmc.edu 13 June 2026
//
// Purpose: Test coverage for the WFI watchdog-timeout logic in privdec.sv.
//
//   privdec.sv computes:
//     WFITimeoutM = ((STATUS_TW & PrivilegeModeW != M_MODE) |
//                    (S_SUPPORTED & PrivilegeModeW == U_MODE)) & WFICount[WFI_TIMEOUT_BIT];
//
//   The timeout-firing cases (S/U-mode) are already covered by the arch tests.
//   This test covers the suppressed case: the watchdog counter saturates
//   (WFICount[WFI_TIMEOUT_BIT] = 1) while the hart is in M-mode with mstatus.TW=1.
//   WFI is always legal in M-mode regardless of TW, so WFITimeoutM must stay 0
//   and no illegal instruction is raised; the hart simply waits for a real
//   interrupt.  Saturating the counter in M-mode with TW=1 exercises the
//   (PrivilegeModeW != M_MODE) and (PrivilegeModeW == U_MODE) FEC terms in their
//   false (no-timeout) direction, which PR #1783 stopped covering incidentally
//   when it made the counter reset on every trap.
//
//   WFI_TIMEOUT_BIT = 16, so the counter saturates after 2^16 = 65536 cycles of
//   continuous WFI.  MTIME increments once per cycle, so a timer deadline of
//   0x14000 (81920) cycles guarantees the counter saturates before the interrupt
//   wakes WFI.
//
//   Checks: the M-mode WFI raised no illegal instruction and woke only for the
//   machine timer interrupt, taken with mepc at the instruction after the WFI,
//   once MTIME reached the deadline (failure index 1).  For contrast, a WFI in
//   S-mode with TW=1 and no interrupt pending must time out to an illegal
//   instruction exception at the WFI.  A trap log checks the sequence of traps
//   (indices 0x100-0x1FF).
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

main:
    la t0, log_trap
    csrw mtvec, t0

    # Set mstatus.TW (bit 21).  TW must not affect WFI legality in M-mode.
    li t0, 0x200000
    csrs mstatus, t0

    # Schedule a machine timer interrupt well past the WFI watchdog timeout.
    li t1, 0x0200BFF8       # MTIME register in CLINT
    ld t2, 0(t1)            # read current MTIME
    li t3, 0x14000          # deadline offset > 2^16 cycles so the watchdog counter saturates first
    add t2, t2, t3          # MTIMECMP = MTIME + offset
    li t1, 0x02004000       # MTIMECMP register in CLINT
    sd t2, 0(t1)
    mv s0, t2               # keep the deadline for the check

    # Wait in M-mode.  The watchdog counter saturates while WFI is still stalled,
    # but WFITimeoutM stays 0 because we are in M-mode, so no illegal instruction
    # is raised.  The hart wakes when the timer interrupt fires.
    wfi
wfi_m_next:
    nop                     # slack for the interrupt-return mepc adjustment in WALLY-init-lib.h
    nop

    # The timer interrupt woke the hart, so MTIME has reached the deadline
    li t1, 0x0200BFF8
    ld a1, 0(t1)
    sltu a1, a1, s0         # 1 if MTIME < deadline
    SC_CHECK_EQ a1, zero, 1

    # In S-mode, TW=1 makes a WFI that does not complete within the time limit an illegal
    # instruction.  The interrupt handler pushed mtimecmp to the maximum, so nothing wakes it.
    li a0, 1
ecall_m1:
    ecall                   # enter supervisor mode
wfi_s:
    wfi
    li a0, 3
ecall_s1:
    ecall                   # back to machine mode

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
1:  .dword 0x8000000000000007, wfi_m_next, 0  # machine timer interrupt after the M-mode WFI retires
    .dword 11, ecall_m1, 0                  # ecall from M
    .dword 2, wfi_s, 0x10500073             # S-mode WFI timed out: illegal instruction
    .dword 9, ecall_s1, 0                   # ecall from S
2:
