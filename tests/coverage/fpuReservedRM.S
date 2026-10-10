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
//          The test checks that each reserved-mode instruction raised an illegal
//          instruction exception at its own address without writing its destination
//          or fflags, that frm holds the value written, and that the legal adds before
//          and after give 1 + 1 = 2 exactly.
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

// CHECKF freg, val, index: check all 64 bits of freg (a single is NaN-boxed)
.macro CHECKF freg, val, index
    fmv.x.d t2, \freg
    li t3, \val
    SC_CHECK_EQ t2, t3, \index
.endm

// CHECKCSR csr, val, index: check that a CSR reads val
.macro CHECKCSR csr, val, index
    csrr t2, \csr
    li t3, \val
    SC_CHECK_EQ t2, t3, \index
.endm

// ILLEGAL_DYN index: f3 = sentinel, then a dynamic-rounding fadd.s, which frm makes reserved.  It must
// raise an illegal instruction exception (mcause 2) at its own address (the library trap handler
// returns past it, so mepc = its address + 4) and leave f3 and fflags unchanged.
.macro ILLEGAL_DYN index
    li t2, 0x5555aaaa5555aaaa
    fmv.d.x f3, t2
    csrw mcause, zero
1:
    fadd.s f3, f1, f2, dyn  // funct3=0b111 (dyn); reserved because FRM_REGW is 5 or 6 -> illegal
    CHECKCSR mcause, 2, \index
    csrr t2, mepc
    la t3, 1b + 4
    SC_CHECK_EQ t2, t3, \index + 1
    CHECKF f3, 0x5555aaaa5555aaaa, \index + 2
    CHECKCSR fflags, 0, \index + 3
.endm

main:

    bseti t0, zero, 14      # mstatus.FS = 0b01 (turn on FPU)
    csrs mstatus, t0

    # A couple of legal FP ops to keep FS live and the FPU exercised
    fli.s f1, 1
    fli.s f2, 1
    fadd.s f3, f1, f2       # legal add with frm = 0 (rne)
    CHECKF f3, 0xffffffff40000000, 1    # 1 + 1 = 2.0, NaN-boxed
    CHECKCSR fflags, 0, 2               # exact

    # ---- Set frm = 5 (reserved), then issue a dynamic-rounding OP-FP op ----
    li t0, 5
    csrw frm, t0            # frm (CSR 0x002) = 0b101 -> fcsr[7:5] = 5
    CHECKCSR frm, 5, 3      # frm holds the reserved value; only its use by a dyn op is illegal
    ILLEGAL_DYN 4

    # ---- Set frm = 6 (reserved), then issue a dynamic-rounding OP-FP op ----
    li t0, 6
    csrw frm, t0            # frm (CSR 0x002) = 0b110 -> fcsr[7:5] = 6
    CHECKCSR frm, 6, 8
    ILLEGAL_DYN 9

    # Restore a legal rounding mode and do a legal op so FPU still works
    li t0, 0
    csrw frm, t0            # frm = rne
    li t2, 0x5555aaaa5555aaaa
    fmv.d.x f3, t2          # sentinel, so the check sees the add write f3
    fadd.s f3, f1, f2
    CHECKF f3, 0xffffffff40000000, 13
    CHECKCSR fcsr, 0, 14    # frm = 0 and no flags

    SC_PASS
    j done
