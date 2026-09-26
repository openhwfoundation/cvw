///////////////////////////////////////////
// fpuReservedRM.S
//
// Written: david_harris@hmc.edu
//
// Purpose: Directed coverage test for src/fpu/fctrl.sv line 98.
//          Hits the focused-expression input terms (FRM_REGW == 5)_1 and
//          (FRM_REGW == 6)_1 in the SupportedRM assignment.
//
//          fctrl.sv:98:
//            assign SupportedRM = ~(Funct3D == 3'b101 | Funct3D == 3'b110 |
//                                  (Funct3D == 3'b111 & (FRM_REGW == 3'b101 |
//                                   FRM_REGW == 3'b110 | FRM_REGW == 3'b111))) | ...
//
//          To make (FRM_REGW == 5) and (FRM_REGW == 6) each evaluate true while
//          the rest of the SupportedRM term is exercised, we set frm (fcsr[7:5])
//          to the reserved values 5 then 6, and execute an OP-FP instruction that
//          uses dynamic rounding (funct3 = 0b111).  This makes SupportedRM false,
//          which marks the instruction illegal.  The library trap handler advances
//          mepc past the illegal instruction so the test continues to "done".
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

    bseti t0, zero, 14      # mstatus.FS = 0b01 (turn on FPU)
    csrs mstatus, t0

    # A couple of legal FP ops to keep FS live and the FPU exercised
    fli.s f1, 1
    fli.s f2, 1
    fadd.s f3, f1, f2       # legal add with implicit (static) rounding

    # ---- Set frm = 5 (reserved), then issue a dynamic-rounding OP-FP op ----
    li t0, 5
    csrw frm, t0            # frm (CSR 0x002) = 0b101 -> fcsr[7:5] = 5
    fadd.s f3, f1, f2, dyn  # funct3=0b111 (dyn); reserved because FRM_REGW==5 -> illegal

    # ---- Set frm = 6 (reserved), then issue a dynamic-rounding OP-FP op ----
    li t0, 6
    csrw frm, t0            # frm (CSR 0x002) = 0b110 -> fcsr[7:5] = 6
    fadd.s f3, f1, f2, dyn  # funct3=0b111 (dyn); reserved because FRM_REGW==6 -> illegal

    # Restore a legal rounding mode and do a legal op so FPU still works
    li t0, 0
    csrw frm, t0            # frm = rne
    fadd.s f3, f1, f2

    j done
