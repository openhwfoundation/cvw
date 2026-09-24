///////////////////////////////////////////
// wfitw.S
//
// Written: David_Harris@hmc.edu 18 September 2026
//
// Purpose: Trap a WFI executed in supervisor mode while mstatus.TW is set.
//
//          privdec.sv raises WFITimeoutM from
//            ((STATUS_TW & (PrivilegeModeW != M_MODE)) | (PrivilegeModeW == U_MODE)) & WFI
//          wfitimeout.S covers the machine-mode case, where TW must not make WFI illegal, and the
//          user-mode case is covered elsewhere, but nothing executed a WFI in supervisor mode with
//          TW set.  That is the only way to reach the rows of this expression that need both
//          STATUS_TW and PrivilegeModeW != M_MODE asserted.
//
//          With TW set and the hart below machine mode, the WFI watchdog counter saturates while
//          the WFI is still stalled and the instruction then raises an illegal instruction
//          exception.  The trap is taken in machine mode because medeleg is clear, and the handler
//          in WALLY-init-lib.h steps over the faulting instruction and returns.
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

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"

main:
    # Push the machine timer far into the future so the watchdog, not an interrupt, ends the WFI.
    li t1, 0x0200BFF8       # MTIME register in CLINT
    ld t2, 0(t1)
    li t3, 0x100000         # well beyond the 2^16 cycle watchdog timeout
    add t2, t2, t3
    li t1, 0x02004000       # MTIMECMP register in CLINT
    sd t2, 0(t1)
    li t0, -1
    csrw stimecmp, t0       # and keep the supervisor timer quiet too

    # Set mstatus.TW (bit 21).  Below machine mode this makes WFI illegal once the watchdog fires.
    li t0, 0x200000
    csrs mstatus, t0

    # Drop to supervisor mode.
    li a0, 1
    ecall

    # Supervisor mode with TW set: the watchdog saturates while this WFI is stalled and it raises
    # an illegal instruction exception, which is taken in machine mode and stepped over.
    wfi
    nop
    nop

    # Back to machine mode, and clear TW so nothing later is affected.
    li a0, 3
    ecall
    li t0, 0x200000
    csrc mstatus, t0

    j done
