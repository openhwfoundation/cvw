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
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

    # Wait in M-mode.  The watchdog counter saturates while WFI is still stalled,
    # but WFITimeoutM stays 0 because we are in M-mode, so no illegal instruction
    # is raised.  The hart wakes when the timer interrupt fires.
    wfi
    nop                     # slack for the interrupt-return mepc adjustment in WALLY-init-lib.h
    nop

    j done
